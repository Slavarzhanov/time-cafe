package main

// Применяет миграции и завершается. Удобно для CI и для `make migrate`.
//
//	go run ./cmd/migrate

import (
	"context"
	"log/slog"
	"os"
	"time"

	"github.com/Slavarzhanov/timecafe/internal/config"
	"github.com/Slavarzhanov/timecafe/internal/db"
)

func main() {
	cfg := config.Load()

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	pool, err := db.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		slog.Error("connect", "err", err)
		os.Exit(1)
	}
	defer pool.Close()

	if err := db.Migrate(ctx, pool); err != nil {
		slog.Error("migrate", "err", err)
		os.Exit(1)
	}

	slog.Info("migrations applied")
}
