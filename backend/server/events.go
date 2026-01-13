package server

import (
	"encoding/json"
	"net/http"
	"pical/database/schemas"
)

func (s *Server) getEvents(w http.ResponseWriter, r *http.Request) {
	events, err := schemas.ListEvents(r.Context(), s.DB)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, events)
}

func (s *Server) createEvent(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()

	var in schemas.Event
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	created, err := schemas.CreateEvent(r.Context(), s.DB, in)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	writeJSON(w, http.StatusCreated, created)
}
