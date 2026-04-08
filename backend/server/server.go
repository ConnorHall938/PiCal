package server

import (
	"context"
	"database/sql"
	"net/http"
	"time"

	"pical/server/endpoints"
)

func New(ctx context.Context, db *sql.DB, frontendDistDir, apiDir string) (*Server, error) {
	s := &Server{
		DB:     db,
		Mux:    http.NewServeMux(),
		Fs:     http.FileServer(http.Dir(frontendDistDir)),
		APIDir: apiDir,
	}

	if err := s.initDatabase(ctx); err != nil {
		return nil, err
	}

	s.routes()
	return s, nil
}

func (s *Server) routes() {
	s.Mux.Handle("/", s.Fs)
	s.Mux.HandleFunc("/health", s.health)
	s.Mux.HandleFunc("/docs", s.serveDocs)
	s.Mux.Handle("/api/", http.StripPrefix("/api/", http.FileServer(http.Dir(s.APIDir))))

	dbTimeout := TimeoutMiddleware(10 * time.Second)

	(&endpoints.EventsDeps{DB: s.DB}).Register(s.Mux, dbTimeout)
	(&endpoints.OccurrenceDeps{DB: s.DB}).Register(s.Mux, dbTimeout)
}

func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}
