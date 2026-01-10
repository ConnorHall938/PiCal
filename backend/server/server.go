package server

import (
	"database/sql"
	"net/http"

	"pical/database/schemas"
)

type Server struct {
	DB  *sql.DB
	Mux *http.ServeMux
	Fs  http.Handler
}

func New(db *sql.DB, frontendDistDir string) *Server {
	s := &Server{
		DB:  db,
		Mux: http.NewServeMux(),
		Fs:  http.FileServer(http.Dir(frontendDistDir)),
	}

	s.routes()
	return s
}

func (s *Server) routes() {
	s.Mux.Handle("/",
		s.Fs,
	)

	s.Mux.HandleFunc("/health", s.health)
	s.Mux.HandleFunc("/events", s.createEvents)
}

func (s *Server) createEvents(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context() // request-scoped context

	targetSchema := schemas.CreateEventSchema()

	if err := schemas.CreateSchema(ctx, s.DB, targetSchema); err != nil {
		http.Error(w, err.Error(), http.StatusServiceUnavailable)
		return
	}

	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	if err := s.DB.PingContext(r.Context()); err != nil {
		http.Error(w, "db not ready", http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}
