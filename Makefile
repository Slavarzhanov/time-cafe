APP          := timecafe
DB_NAME      ?= timecafe
DB_USER      ?= postgres
DB_HOST      ?= localhost
DB_PORT      ?= 5432
DATABASE_URL ?= postgres://$(DB_USER):postgres@$(DB_HOST):$(DB_PORT)/$(DB_NAME)?sslmode=disable

.PHONY: help run build test vet fmt tidy lint db-create migrate seed

help:
	@echo run        - запустить приложение
	@echo build      - собрать бинарник в bin/
	@echo test       - прогнать тесты
	@echo vet        - статический анализ
	@echo fmt        - форматирование gofmt
	@echo tidy       - обновить go.mod/go.sum
	@echo db-create  - создать базу $(DB_NAME)
	@echo migrate    - применить миграции
	@echo seed       - загрузить демо-данные

run:
	go run ./cmd/timecafe

build:
	go build -o bin/$(APP).exe ./cmd/timecafe

test:
	go test ./...

vet:
	go vet ./...

fmt:
	gofmt -w .

tidy:
	go mod tidy

lint:
	golangci-lint run

db-create:
	createdb -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) $(DB_NAME)

migrate:
	go run ./cmd/migrate

seed:
	psql "$(DATABASE_URL)" -f seeds/dev.sql
