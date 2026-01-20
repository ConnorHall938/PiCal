package server

import (
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"pical/database/schemas"
)

func (s *Server) getEvents(w http.ResponseWriter, r *http.Request) {
	limit := parseIntQuery(r, "limit", 50, 1, 200)
	offset := parseIntQuery(r, "offset", 0, 0, 1_000_000)

	items, total, err := schemas.ListEvents(r.Context(), s.DB, limit, offset)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	resp := PagedResponse[schemas.Event]{
		Items:  items,
		Limit:  limit,
		Offset: offset,
		Count:  len(items),
		Total:  total,
	}

	writeJSON(w, http.StatusOK, resp)
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

func (s *Server) deleteEvent(w http.ResponseWriter, r *http.Request, id string) {

	err := schemas.DeleteEvent(r.Context(), s.DB, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "event not found", http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) getEvent(w http.ResponseWriter, r *http.Request, id string) {

	out, err := schemas.GetEvent(r.Context(), s.DB, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "event not found", http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusCreated, out)
}
