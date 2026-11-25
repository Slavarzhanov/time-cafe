# База данных TimeCafe

Владелец раздела — агент `db`. Здесь **карта** схемы и расхождений, а не копия
DDL: точные колонки всегда смотри в миграциях.

## 1. Два источника схемы

| Файл | Роль | Применяет раннер? |
|---|---|---|
| `migrations/000001_init.up.sql` + `.down.sql` | реальная миграция каркаса | **да** |
| `migrations/00002_init_sql_test.sql` | ERD-скрипт из pgAdmin, ориентир целевой схемы | нет |
| `migrations/checks.sql` | CHECK-ограничения, идемпотентные | нет |

Раннер [`internal/db/migrate.go`](../../internal/db/migrate.go) берёт только
`*.up.sql`, сортирует по имени и оборачивает каждый файл в транзакцию. Поэтому
`BEGIN`/`COMMIT` внутри файла писать нельзя.

## 2. Что реально создаёт `000001_init.up.sql`

| Объект | Назначение | Замечание |
|---|---|---|
| `users` | учётные записи администраторов | `login UNIQUE`, `role` = `admin`/`manager` |
| `guests` | гости | история и скидка должны быть здесь |
| `cards` | карты | сейчас есть постоянная `guest_id` — противоречит ТЗ |
| `tariffs` | тарифы | целевая модель — `rooms` |
| `services` | услуги | цена в копейках |
| `visits` | визиты | `EXCLUDE` не даёт два активных визита гостю |
| `visit_services` | услуги в визите | `price_at_moment`, `amount` — generated |
| `transactions` | проводки по карте | модель баланса, противоречит постоплате |
| `card_balances` (view) | баланс карты | подлежит удалению |
| `audit_log` | аудит действий | `payload JSONB` |
| `settings` | настройки | key/value |

## 3. Целевая модель по ТЗ v2.0

| Таблица | Что меняется |
|---|---|
| `guests` | добавляются `discount_type` (`percent`/`fixed`) и `discount_value`; депозит — П2 |
| `cards` | убрать постоянную привязку к гостю; `uid TEXT` + `printed_number`; статусы `free`/`in_use`/`blocked`/`lost` |
| `rooms` | вместо `tariffs`: `price_per_hour`, `min_minutes`, `rounding_minutes`, `capacity` |
| `visits` | `guest_id`, `room_id`, `shift_id NOT NULL`; `status`, `started_at`, `finished_at`, суммы |
| `payments` | новая: `visit_id`, `method`, `amount`, `receipt_number`, `created_by` |
| `shifts` | `opened_at`, `closed_at`, `opened_by`, `closed_by`; запрет закрытия с активными визитами |
| `reservations` | `guest_id`, `room_id`, интервал, `status`; запрет пересечений |
| `users`, `roles`, `employees`, `professions` | учётные записи отдельно от кадров |
| `audit_log`, `settings` | остаются |

## 4. Известные расхождения и блокеры

1. **Постоянная привязка карты.** `cards.guest_id` в `000001_init.up.sql:37`
   противоречит решению D6 (карты оборотные).
2. **Баланс карты.** `transactions` + view `card_balances`
   (`000001_init.up.sql:119-155`) противоречат D3 (постоплата, без баланса).
3. **Тарифы вместо комнат.** `tariffs` (`000001_init.up.sql:47-58`) не совпадает
   с D8 (цена за час, `min_minutes`, `rounding_minutes` у комнаты).
4. **Разные схемы.** `000001` работает в `public`, а ERD и `checks.sql` — в
   `timecafeschema`. Нужно выбрать `public` и убрать префикс.
5. **`00002_init_sql_test.sql` не запускается:**
   - `UNIQUE (role_name) INCLUDE(role_name)` — колонка дважды в индексе (`:117-118`);
   - `UNIQUE (user_employee_id) INCLUDE(user_employee_id)` — то же (`:130-131`);
   - нет `CREATE SCHEMA timecafeschema`;
   - справочник `statuses` пуст;
   - `shifts.shift_end NOT NULL` не даёт открыть смену (`:81`);
   - `users.user_login` без `UNIQUE` (`:124`);
   - опечатки `extrasevice`, `exrtaservice`, `quontity` (`:138-140`).
6. **`checks.sql` не применяется раннером.** Его нужно либо запускать вручную,
   либо перенести в отдельную миграцию.
7. **Скидка на карте.** В ERD `discounts` висит на `cards` (`:22`), а по ТЗ
   скидка принадлежит гостю.

## 5. Соглашения

- Схема — `public`; префиксы в именах таблиц не используем.
- ID — `BIGINT GENERATED ALWAYS AS IDENTITY`.
- Деньги — `BIGINT` в копейках, `CHECK (>= 0)` где применимо.
- Время — `TIMESTAMPTZ`; хранение UTC.
- Статусы — `TEXT` + `CHECK`, без enum-типов.
- UID — `TEXT`, `CHECK (uid ~ '^[0-9A-F]{10}$')`, `UNIQUE`.
- Один активный визит гостя — частичный `EXCLUDE`/`UNIQUE`.
- Пересечения броней — `EXCLUDE USING gist` (нужен `btree_gist`).
- Имена — `snake_case`, таблицы во множественном числе.
- `down`-миграция удаляет объекты в обратном порядке.

## 6. Как проверять

`psql` не в `PATH`; на Windows бинарники лежат в
`C:\Program Files\PostgreSQL\18\bin`.

```powershell
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
& $psql -h localhost -p 5432 -U postgres -d timecafe_test -v ON_ERROR_STOP=1 -f migrations/000001_init.up.sql
& $psql -h localhost -p 5432 -U postgres -d timecafe_test -v ON_ERROR_STOP=1 -f migrations/checks.sql
& $psql -h localhost -p 5432 -U postgres -d timecafe_test -v ON_ERROR_STOP=1 -f migrations/checks.sql  # должен пройти повторно
& $psql -h localhost -p 5432 -U postgres -d timecafe_test -v ON_ERROR_STOP=1 -f migrations/000001_init.down.sql
```

Тесты БД — в `tests/db/`, их пишет и поддерживает `qa-db`.

## 7. Как отвечать другим агентам

На вопрос «где лежит поле» отвечай точно:

```
visits.finished_at TIMESTAMPTZ NULL
  — migrations/000001_init.up.sql:80
  — заполняется при закрытии, CHECK visits_closed_has_finished_at (:91-92)
```

Если факта нет в файлах — сначала посмотри `\d+ <table>` в живой БД, затем
скажи «в текущей схеме такого нет». Не выдумывай колонки.
