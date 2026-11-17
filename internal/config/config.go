package config

import (
	"bufio"
	"os"
	"strconv"
	"strings"
)

// Config хранит настройки приложения, получаемые из переменных окружения.
type Config struct {
	Env            string
	Addr           string
	DatabaseURL    string
	MigrateOnStart bool
}

// Load читает конфигурацию из окружения и подставляет значения по умолчанию.
// Если рядом лежит файл .env, его значения подхватываются, но не перекрывают
// уже установленные переменные окружения.
func Load() Config {
	loadDotEnv(".env")

	return Config{
		Env:            getenv("APP_ENV", "dev"),
		Addr:           getenv("APP_ADDR", ":8080"),
		DatabaseURL:    getenv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/timecafe?sslmode=disable"),
		MigrateOnStart: getenvBool("MIGRATE_ON_START", true),
	}
}

func loadDotEnv(path string) {
	file, err := os.Open(path)
	if err != nil {
		return
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}

		key = strings.TrimSpace(key)
		value = strings.Trim(strings.TrimSpace(value), `"'`)
		if key == "" {
			continue
		}

		if _, exists := os.LookupEnv(key); exists {
			continue
		}
		_ = os.Setenv(key, value)
	}
}

func getenv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok && value != "" {
		return value
	}
	return fallback
}

func getenvBool(key string, fallback bool) bool {
	value, ok := os.LookupEnv(key)
	if !ok || value == "" {
		return fallback
	}
	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}
	return parsed
}
