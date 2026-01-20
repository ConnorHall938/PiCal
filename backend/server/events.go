package server

import (
	"encoding/json"
	"net/http"
	"pical/database/schemas"
	"strconv"
)

func parseIntQuery(r *http.Request, key string, def, min, max int) int {
	v := r.URL.Query().Get(key)
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return def
	}
	if n < min {
		return min
	}
	if n > max {
		return max
	}
	return n
}

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
