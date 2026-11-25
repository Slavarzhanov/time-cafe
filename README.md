# Тайм-кафе — веб-приложение

Дипломный проект: веб-приложение для тайм-кафе с учётом времени по картам
и записью дополнительных услуг.

**Стек:** Go 1.25+ · PostgreSQL 16+ · Go templates + HTMX
**Считыватель:** Smartec ST-CE011EM (EM-Marine 125 кГц, USB HID)
**План работ:** [ROADMAP.md](ROADMAP.md) · [параллельный план на двоих](ROADMAP-TEAM.md)
**Техническое задание:** [ТЗ.md](ТЗ.md)

---

## Требования

- Go 1.25 или новее
- PostgreSQL 16+ (проверено на 18)
- `psql` / `createdb` в `PATH` — на Windows лежат в
  `C:\Program Files\PostgreSQL\18\bin`

## Быстрый старт

```powershell
# 1. Скопировать настройки и указать свой пароль от postgres
copy .env.example .env

# 2. Создать базу
createdb -U postgres timecafe

# 3. Запустить: миграции применятся автоматически
go run ./cmd/timecafe
```

Приложение: <http://localhost:8080> · Проверка: <http://localhost:8080/healthz>

Демо-данные (тарифы, услуги, гости, карты):

```powershell
psql "postgres://postgres:ПАРОЛЬ@localhost:5432/timecafe?sslmode=disable" -f seeds/dev.sql
```

## Команды

| Команда | Что делает |
|---|---|
| `make run` | запуск приложения |
| `make build` | сборка в `bin/timecafe.exe` |
| `make test` | тесты |
| `make vet` | `go vet` |
| `make migrate` | только миграции |
| `make seed` | демо-данные |

Без `make` те же команды: `go run ./cmd/timecafe`, `go run ./cmd/migrate`,
`go test ./...`.

## Структура

```
cmd/
  timecafe/        точка входа приложения
  migrate/         применение миграций
  hashpw/          генерация bcrypt-хеша пароля
internal/
  config/          конфигурация из env и .env
  db/              пул соединений и раннер миграций
  server/          HTTP-маршруты и рендеринг шаблонов
migrations/        SQL-миграции (встроены в бинарник через embed)
seeds/             демонстрационные данные
web/               шаблоны и статика (встроены через embed)
```

## Соглашения

- **Деньги** — `BIGINT` в копейках. Никаких `float`.
- **Время** — `TIMESTAMPTZ`.
- **UID карты** — канонический вид: 10 hex-символов в верхнем регистре
  (5 байт EM-Marine). Нормализация выполняется на входе, до записи в БД.
- **Цена услуги** фиксируется в `visit_services.price_at_moment`,
  поэтому изменение прайса не переписывает старые чеки.
- **Оплата** — постоплатой при закрытии визита; баланса на карте нет.
  Текущая миграция `000001` ещё содержит старую модель проводок — см.
  [`docs/knowledge/db.md`](docs/knowledge/db.md).
- Ветки: `feat/<id>-<short-name>`; коммиты — Conventional Commits.

## Для участников и агентов

- [`AGENTS.md`](AGENTS.md) — правила проекта и карта субагентов.
- [`docs/knowledge/`](docs/knowledge/README.md) — общие знания: домен, БД, API, UI, решения.
- [`docs/design/stylebook.md`](docs/design/stylebook.md) — стайлбук.
- [`docs/qa/README.md`](docs/qa/README.md) — стратегия тестирования и отчёты.
- [`docs/report/`](docs/report/README.md) — текст ПЗ и замечания.

Субагенты лежат в `.opencode/agents/`: `db`, `backend`, `frontend`, `style`,
`report`, `qa-db`, `qa-backend`, `qa-frontend`.

## Статус

Реализованы: каркас приложения, конфигурация, миграции, health-check,
базовый layout. Дальше по плану — слой доступа к данным и доменный расчёт
стоимости (см. ROADMAP, вехи M1–M2).
