-- ============================================================================
-- CHECK-ограничения для схемы timecafeschema
--
-- Назначение: проверка входных значений на уровне базы данных.
--
-- Это НЕ миграция: раннер применяет только файлы вида *.up.sql, поэтому
-- файл запускается вручную после скрипта, сгенерированного из pgAdmin ERD:
--
--   psql -d timecafe -f migrations/00002_init_sql_test.sql
--   psql -d timecafe -f migrations/checks.sql
--
-- Повторный запуск безопасен: каждое ограничение пересоздаётся
-- (DROP CONSTRAINT IF EXISTS + ADD CONSTRAINT).
--
-- При переносе в миграции уберите BEGIN/COMMIT: транзакцией управляет раннер.
-- ============================================================================

BEGIN;

-- Справочники ---------------------------------------------------------------

ALTER TABLE timecafeschema.discounts
    DROP CONSTRAINT IF EXISTS discounts_percent_ck,
    ADD  CONSTRAINT discounts_percent_ck
        CHECK (discount_value_percent BETWEEN 0 AND 100);

ALTER TABLE timecafeschema.statuses
    DROP CONSTRAINT IF EXISTS statuses_name_ck,
    ADD  CONSTRAINT statuses_name_ck
        CHECK (btrim(status_name) <> '');

ALTER TABLE timecafeschema.roles
    DROP CONSTRAINT IF EXISTS roles_name_ck,
    ADD  CONSTRAINT roles_name_ck
        CHECK (btrim(role_name) <> '');

ALTER TABLE timecafeschema.professions
    DROP CONSTRAINT IF EXISTS professions_name_ck,
    ADD  CONSTRAINT professions_name_ck
        CHECK (btrim(profession_name) <> '');

-- Карты ---------------------------------------------------------------------

ALTER TABLE timecafeschema.cards
    DROP CONSTRAINT IF EXISTS cards_number_ck,
    ADD  CONSTRAINT cards_number_ck
        CHECK (card_number > 0);

-- Услуги --------------------------------------------------------------------

ALTER TABLE timecafeschema.extraservices
    DROP CONSTRAINT IF EXISTS extraservices_name_ck,
    ADD  CONSTRAINT extraservices_name_ck
        CHECK (btrim(extraservice_name) <> ''),
    DROP CONSTRAINT IF EXISTS extraservices_price_ck,
    ADD  CONSTRAINT extraservices_price_ck
        CHECK (extraservice_price >= 0);

-- Комнаты -------------------------------------------------------------------

ALTER TABLE timecafeschema.rooms
    DROP CONSTRAINT IF EXISTS rooms_name_ck,
    ADD  CONSTRAINT rooms_name_ck
        CHECK (btrim(room_name) <> ''),
    DROP CONSTRAINT IF EXISTS rooms_price_ck,
    ADD  CONSTRAINT rooms_price_ck
        CHECK (room_price > 0),
    DROP CONSTRAINT IF EXISTS rooms_persons_ck,
    ADD  CONSTRAINT rooms_persons_ck
        CHECK (room_persons IS NULL OR room_persons > 0);

-- Сотрудники ----------------------------------------------------------------

ALTER TABLE timecafeschema.employees
    DROP CONSTRAINT IF EXISTS employees_name_ck,
    ADD  CONSTRAINT employees_name_ck
        CHECK (btrim(employee_surname) <> '' AND btrim(employee_name) <> '');

-- Учётные записи ------------------------------------------------------------

ALTER TABLE timecafeschema.users
    DROP CONSTRAINT IF EXISTS users_login_ck,
    ADD  CONSTRAINT users_login_ck
        CHECK (user_login ~ '^[A-Za-z0-9_.-]{3,32}$');

-- Смены ---------------------------------------------------------------------

ALTER TABLE timecafeschema.shifts
    DROP CONSTRAINT IF EXISTS shifts_period_ck,
    ADD  CONSTRAINT shifts_period_ck
        CHECK (shift_end IS NULL OR shift_end > shift_start);

-- Визиты --------------------------------------------------------------------

ALTER TABLE timecafeschema.visits
    DROP CONSTRAINT IF EXISTS visits_period_ck,
    ADD  CONSTRAINT visits_period_ck
        CHECK (visit_end IS NULL OR visit_end >= visit_start),
    DROP CONSTRAINT IF EXISTS visits_cost_ck,
    ADD  CONSTRAINT visits_cost_ck
        CHECK (visit_final_cost IS NULL OR visit_final_cost >= 0);

-- Закрытый визит обязан иметь время окончания и итог.
-- Включать после того, как зафиксируете id статусов (1 = active,
-- 2 = closed, 3 = canceled), иначе проверка будет ссылаться на чужой id.
--
-- ALTER TABLE timecafeschema.visits
--     DROP CONSTRAINT IF EXISTS visits_closed_ck,
--     ADD  CONSTRAINT visits_closed_ck
--         CHECK (visit_status <> 2
--                OR (visit_end IS NOT NULL AND visit_final_cost IS NOT NULL));

-- Брони ---------------------------------------------------------------------

ALTER TABLE timecafeschema.reservations
    DROP CONSTRAINT IF EXISTS reservations_period_ck,
    ADD  CONSTRAINT reservations_period_ck
        CHECK (reservation_end IS NULL OR reservation_end > reservation_start),
    DROP CONSTRAINT IF EXISTS reservations_client_ck,
    ADD  CONSTRAINT reservations_client_ck
        CHECK (btrim(reservation_client_name) <> ''
           AND btrim(reservation_client_phone) <> '');

-- Услуги в визите -----------------------------------------------------------
-- Имена колонок взяты как в текущей схеме, с опечатками:
-- quontity -> quantity, exrtaservice -> extraservice.

ALTER TABLE timecafeschema.visits_extraservices
    DROP CONSTRAINT IF EXISTS ves_quantity_ck,
    ADD  CONSTRAINT ves_quantity_ck
        CHECK (visit_extraservice_quontity > 0),
    DROP CONSTRAINT IF EXISTS ves_price_ck,
    ADD  CONSTRAINT ves_price_ck
        CHECK (visit_exrtaservice_price_at_adding_moment >= 0);

COMMIT;
