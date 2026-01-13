package server

import (
	"context"
	"database/sql"
	"net/http"
)

type Server struct {
	DB  *sql.DB
	Mux *http.ServeMux
	Fs  http.Handler
}

func New(ctx context.Context, db *sql.DB, frontendDistDir string) (*Server, error) {
	s := &Server{
		DB:  db,
		Mux: http.NewServeMux(),
		Fs:  http.FileServer(http.Dir(frontendDistDir)),
	}

	err := s.initDatabase(ctx)
	if err != nil {
		return nil, err
	}

	s.routes()
	return s, nil
}

func (s *Server) routes() {
	s.Mux.Handle("/",
		s.Fs,
	)

	s.Mux.HandleFunc("/health", s.health)
}

func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	if err := s.DB.PingContext(r.Context()); err != nil {
		http.Error(w, "db not ready", http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}
