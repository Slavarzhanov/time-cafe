-- 000001_init: базовая схема тайм-кафе.
--
-- Соглашения:
--   * деньги хранятся целыми числами в копейках (BIGINT), никогда не float;
--   * время — TIMESTAMPTZ;
--   * статусы — TEXT + CHECK, чтобы не усложнять миграции enum-типами.

-- Нужен для EXCLUDE-ограничения по guest_id в таблице visits.
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE users (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    login         TEXT        NOT NULL UNIQUE,
    password_hash TEXT        NOT NULL,
    full_name     TEXT        NOT NULL DEFAULT '',
    -- admin: полный доступ, manager: рабочее место администратора без настроек
    role          TEXT        NOT NULL DEFAULT 'manager'
                              CHECK (role IN ('admin', 'manager')),
    is_active     BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE guests (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name  TEXT        NOT NULL,
    phone      TEXT,
    notes      TEXT        NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Карта — ключ доступа. Баланс и история хранятся в БД, а не на самой карте.
-- uid хранится в каноническом виде: 5 байт EM-Marine => 10 hex-символов в верхнем регистре.
CREATE TABLE cards (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uid        TEXT        NOT NULL UNIQUE
                           CHECK (uid ~ '^[0-9A-F]{10}$'),
    guest_id   BIGINT      REFERENCES guests (id) ON DELETE SET NULL,
    status     TEXT        NOT NULL DEFAULT 'active'
                           CHECK (status IN ('active', 'blocked', 'lost')),
    issued_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    blocked_at TIMESTAMPTZ,
    check (status = 'active' OR blocked_at IS NOT NULL)
);

CREATE INDEX cards_guest_id_idx ON cards (guest_id);

CREATE TABLE tariffs (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name             TEXT        NOT NULL,
    billing_type     TEXT        NOT NULL
                                 CHECK (billing_type IN ('per_minute', 'per_hour')),
    price            BIGINT      NOT NULL CHECK (price > 0),
    min_minutes      INTEGER     NOT NULL DEFAULT 0 CHECK (min_minutes >= 0),
    rounding_minutes INTEGER     NOT NULL DEFAULT 1 CHECK (rounding_minutes > 0),
    valid_from       DATE        NOT NULL DEFAULT CURRENT_DATE,
    is_active        BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE services (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       TEXT        NOT NULL,
    category   TEXT        NOT NULL DEFAULT 'other',
    price      BIGINT      NOT NULL CHECK (price >= 0),
    unit       TEXT        NOT NULL DEFAULT 'шт',
    is_active  BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX services_category_idx ON services (category) WHERE is_active;

CREATE TABLE visits (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    guest_id        BIGINT      NOT NULL REFERENCES guests (id) ON DELETE RESTRICT,
    card_id         BIGINT      NOT NULL REFERENCES cards (id) ON DELETE RESTRICT,
    tariff_id       BIGINT      NOT NULL REFERENCES tariffs (id) ON DELETE RESTRICT,
    status          TEXT        NOT NULL DEFAULT 'active'
                                CHECK (status IN ('active', 'closed', 'canceled')),
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at     TIMESTAMPTZ,
    billed_minutes  INTEGER     NOT NULL DEFAULT 0 CHECK (billed_minutes >= 0),
    time_amount     BIGINT      NOT NULL DEFAULT 0 CHECK (time_amount >= 0),
    services_amount BIGINT      NOT NULL DEFAULT 0 CHECK (services_amount >= 0),
    discount_amount BIGINT      NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    total_amount    BIGINT      NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    opened_by       BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    closed_by       BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT visits_finished_after_started
        CHECK (finished_at IS NULL OR finished_at >= started_at),
    CONSTRAINT visits_closed_has_finished_at
        CHECK (status <> 'closed' OR finished_at IS NOT NULL),
    -- один гость не может иметь два открытых визита одновременно
    CONSTRAINT visits_one_active_per_guest EXCLUDE USING gist (
        guest_id WITH =,
        tstzrange(started_at, COALESCE(finished_at, 'infinity'::timestamptz)) WITH &&
    ) WHERE (status = 'active')
);

CREATE INDEX visits_status_started_idx ON visits (status, started_at DESC);
CREATE INDEX visits_card_id_idx ON visits (card_id);
CREATE INDEX visits_guest_id_idx ON visits (guest_id);

CREATE TABLE visit_services (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    visit_id        BIGINT      NOT NULL REFERENCES visits (id) ON DELETE CASCADE,
    service_id      BIGINT      NOT NULL REFERENCES services (id) ON DELETE RESTRICT,
    qty             INTEGER     NOT NULL DEFAULT 1 CHECK (qty > 0),
    -- цена фиксируется в момент добавления: изменение прайса не меняет старые чеки
    price_at_moment BIGINT      NOT NULL CHECK (price_at_moment >= 0),
    amount          BIGINT      GENERATED ALWAYS AS (qty * price_at_moment) STORED,
    added_by        BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    added_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX visit_services_visit_id_idx ON visit_services (visit_id);
CREATE INDEX visit_services_service_id_idx ON visit_services (service_id);

-- Проводки по карте. Положительная сумма — пополнение, отрицательная — списание.
-- Инвариант: баланс карты = SUM(amount) по всем её проводкам.
CREATE TABLE transactions (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    card_id    BIGINT      NOT NULL REFERENCES cards (id) ON DELETE RESTRICT,
    visit_id   BIGINT      REFERENCES visits (id) ON DELETE SET NULL,
    type       TEXT        NOT NULL CHECK (type IN (
                               'deposit',
                               'time_payment',
                               'service_payment',
                               'refund',
                               'adjustment'
                           )),
    amount     BIGINT      NOT NULL CHECK (amount <> 0),
    method     TEXT        NOT NULL DEFAULT 'none'
                           CHECK (method IN ('cash', 'card', 'none')),
    comment    TEXT        NOT NULL DEFAULT '',
    created_by BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT transactions_sign_matches_type CHECK (
        (type = 'deposit' AND amount > 0) OR
        (type = 'refund'  AND amount > 0) OR
        (type IN ('time_payment', 'service_payment') AND amount < 0) OR
        (type = 'adjustment')
    )
);

CREATE INDEX transactions_card_created_idx ON transactions (card_id, created_at DESC);
CREATE INDEX transactions_visit_id_idx ON transactions (visit_id) WHERE visit_id IS NOT NULL;

CREATE VIEW card_balances AS
SELECT c.id   AS card_id,
       c.uid  AS uid,
       COALESCE(SUM(t.amount), 0) AS balance
FROM cards c
LEFT JOIN transactions t ON t.card_id = c.id
GROUP BY c.id, c.uid;

CREATE TABLE audit_log (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT      REFERENCES users (id) ON DELETE SET NULL,
    action     TEXT        NOT NULL,
    entity     TEXT        NOT NULL,
    entity_id  BIGINT,
    payload    JSONB       NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX audit_log_created_idx ON audit_log (created_at DESC);
CREATE INDEX audit_log_entity_idx ON audit_log (entity, entity_id);

CREATE TABLE settings (
    key        TEXT PRIMARY KEY,
    value      TEXT        NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO settings (key, value) VALUES
    ('cafe.name', 'Тайм-кафе'),
    ('card.uid_format', 'hex10'),
    ('visit.grace_minutes', '5');
