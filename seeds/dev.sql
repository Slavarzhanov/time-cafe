-- Демонстрационные данные для разработки. Не является миграцией.
-- Запуск: make seed (требуется psql в PATH).
--
-- Пароль всех пользователей: admin123 (bcrypt, cost 10).
-- Хеш перегенерируется командой: go run ./cmd/hashpw -password admin123

BEGIN;

INSERT INTO users (login, password_hash, full_name, role)
VALUES
    ('admin',   '$2a$10$bVKJ1xQs1gZ.ce1.5GeR0erqhuIaUROYWTDdxGd4wQfDIvZcOXn2a', 'Администратор', 'admin'),
    ('manager', '$2a$10$bVKJ1xQs1gZ.ce1.5GeR0erqhuIaUROYWTDdxGd4wQfDIvZcOXn2a', 'Смена 1', 'manager')
ON CONFLICT (login) DO NOTHING;

INSERT INTO tariffs (name, billing_type, price, min_minutes, rounding_minutes)
VALUES
    ('Стандарт',   'per_minute', 300, 30, 1),
    ('Час',        'per_hour',   15000, 60, 60),
    ('Дневной',    'per_hour',   12000, 240, 60);

INSERT INTO services (name, category, price, unit)
VALUES
    ('Кофе американо',   'drinks', 15000, 'шт'),
    ('Капучино',         'drinks', 18000, 'шт'),
    ('Чай',              'drinks', 12000, 'шт'),
    ('Пицца Маргарита',  'food',   45000, 'шт'),
    ('Сэндвич',          'food',   30000, 'шт'),
    ('Настольная игра',  'games',  20000, 'шт'),
    ('PlayStation',      'games',  30000, 'час'),
    ('Принтер',          'other',  1000,  'шт');

INSERT INTO guests (full_name, phone)
VALUES
    ('Иван Петров',    '+7 900 000-00-01'),
    ('Мария Сидорова', '+7 900 000-00-02');

INSERT INTO cards (uid, guest_id)
SELECT '0000000001', id FROM guests WHERE full_name = 'Иван Петров';
INSERT INTO cards (uid, guest_id)
SELECT '0000000002', id FROM guests WHERE full_name = 'Мария Сидорова';

INSERT INTO transactions (card_id, type, amount, method, comment)
SELECT id, 'deposit', 100000, 'cash', 'Стартовый депозит'
FROM cards WHERE uid IN ('0000000001', '0000000002');

COMMIT;
