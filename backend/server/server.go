package server

import (
	"context"
	"database/sql"
	"net/http"
	"strings"
	"time"
)

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

	dbTimeoutMiddleware := TimeoutMiddleware(10 * time.Second)

	s.Mux.Handle("/events", dbTimeoutMiddleware(http.HandlerFunc(s.eventHandler)))
	s.Mux.Handle("/events/", dbTimeoutMiddleware(http.HandlerFunc(s.eventByIDHandler)))
}

func (s *Server) eventHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		s.getEvents(w, r)
	case http.MethodPost:
		s.createEvent(w, r)
	default:
		w.Header().Set("Allow", "GET, POST")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *Server) eventByIDHandler(w http.ResponseWriter, r *http.Request) {
	// Path is like "/events/{id}" (because this handler is registered at "/events/")
	id := strings.TrimPrefix(r.URL.Path, "/events/")
	id = strings.Trim(id, "/") // defensive: "/events/{id}/"

	// Reject "/events/" (no id) and deeper paths like "/events/a/b"
	if id == "" || strings.Contains(id, "/") {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}

	switch r.Method {
	case http.MethodGet:
		s.getEvent(w, r, id)
	case http.MethodDelete:
		s.deleteEvent(w, r, id)
	default:
		w.Header().Set("Allow", "GET, DELETE")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	if err := s.DB.PingContext(r.Context()); err != nil {
		http.Error(w, "db not ready", http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}
