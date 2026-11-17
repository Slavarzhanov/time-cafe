-- 000001_init (down): полный откат базовой схемы.

DROP VIEW IF EXISTS card_balances;

DROP TABLE IF EXISTS audit_log;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS visit_services;
DROP TABLE IF EXISTS visits;
DROP TABLE IF EXISTS services;
DROP TABLE IF EXISTS tariffs;
DROP TABLE IF EXISTS cards;
DROP TABLE IF EXISTS guests;
DROP TABLE IF EXISTS users;

DROP TABLE IF EXISTS settings;
