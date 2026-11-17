package server

import (
	"context"
	"encoding/json"
	"html/template"
	"log/slog"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Slavarzhanov/timecafe/web"
)

// pageNames — все страницы, которые рендерятся через общий layout.
var pageNames = []string{"index.html"}

// Server связывает HTTP-обработчики с зависимостями приложения.
type Server struct {
	pool  *pgxpool.Pool
	pages map[string]*template.Template
}

// New создаёт сервер и заранее разбирает шаблоны — ошибка шаблона
// обнаруживается при старте, а не в момент запроса.
func New(pool *pgxpool.Pool) *Server {
	return &Server{
		pool:  pool,
		pages: parseTemplates(),
	}
}

func parseTemplates() map[string]*template.Template {
	base := template.Must(template.New("").ParseFS(web.FS, "templates/layout.html"))

	pages := make(map[string]*template.Template, len(pageNames))
	for _, name := range pageNames {
		clone, err := base.Clone()
		if err != nil {
			panic(err)
		}
		pages[name] = template.Must(clone.ParseFS(web.FS, "templates/"+name))
	}
	return pages
}

// Routes собирает маршруты приложения.
func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", s.handleHealth)
	mux.Handle("GET /static/", http.StripPrefix("/static/", http.FileServer(http.FS(web.Static()))))
	mux.HandleFunc("GET /{$}", s.handleIndex)

	return logRequests(mux)
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	status := "ok"
	dbStatus := "ok"
	code := http.StatusOK

	if err := s.pool.Ping(ctx); err != nil {
		status = "degraded"
		dbStatus = "unavailable"
		code = http.StatusServiceUnavailable
	}

	writeJSON(w, code, map[string]string{
		"status": status,
		"db":     dbStatus,
	})
}

func (s *Server) handleIndex(w http.ResponseWriter, r *http.Request) {
	data := map[string]any{
		"Title": "Тайм-кафе — рабочее место администратора",
	}
	s.render(w, "index.html", data)
}

func (s *Server) render(w http.ResponseWriter, page string, data any) {
	tpl, ok := s.pages[page]
	if !ok {
		http.Error(w, "template not found", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := tpl.ExecuteTemplate(w, "layout", data); err != nil {
		slog.Error("render template", "page", page, "err", err)
	}
}

func writeJSON(w http.ResponseWriter, code int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		slog.Error("write json", "err", err)
	}
}

// logRequests пишет метод, путь, статус и длительность обработки.
func logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}

		next.ServeHTTP(rec, r)

		slog.Info("request",
			"method", r.Method,
			"path", r.URL.Path,
			"status", rec.status,
			"duration", time.Since(started).String(),
		)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}
