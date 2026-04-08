package endpoints

import (
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"pical/database/schemas"
	"pical/server/utils"
)

type EventsDeps struct {
	DB *sql.DB
}

func (d *EventsDeps) Register(mux *http.ServeMux, wrap func(http.Handler) http.Handler) {
	mux.Handle("/events", wrap(http.HandlerFunc(d.CollectionHandler)))
	mux.Handle("/events/", wrap(http.HandlerFunc(d.ItemHandler)))
}

func (d *EventsDeps) CollectionHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		d.getEvents(w, r)
	case http.MethodPost:
		d.createEvent(w, r)
	default:
		w.Header().Set("Allow", "GET, POST")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func (d *EventsDeps) ItemHandler(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/events/")
	id = strings.Trim(id, "/")

	if id == "" || strings.Contains(id, "/") {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}

	switch r.Method {
	case http.MethodGet:
		d.getEvent(w, r, id)
	case http.MethodDelete:
		d.deleteEvent(w, r, id)
	default:
		w.Header().Set("Allow", "GET, DELETE")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func (d *EventsDeps) getEvents(w http.ResponseWriter, r *http.Request) {
	limit := utils.ParseIntQuery(r, "limit", 50, 1, 200)
	offset := utils.ParseIntQuery(r, "offset", 0, 0, 1_000_000)

	items, total, err := schemas.ListEvents(r.Context(), d.DB, limit, offset)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	utils.WriteJSON(w, http.StatusOK, utils.PagedResponse[schemas.Event]{
		Items:  items,
		Limit:  limit,
		Offset: offset,
		Count:  len(items),
		Total:  total,
	})
}

func (d *EventsDeps) createEvent(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()

	var in schemas.Event
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	created, err := schemas.CreateEvent(r.Context(), d.DB, in)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	utils.WriteJSON(w, http.StatusCreated, created)
}

func (d *EventsDeps) getEvent(w http.ResponseWriter, r *http.Request, id string) {
	out, err := schemas.GetEvent(r.Context(), d.DB, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "event not found", http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	utils.WriteJSON(w, http.StatusOK, out)
}

func (d *EventsDeps) deleteEvent(w http.ResponseWriter, r *http.Request, id string) {
	err := schemas.DeleteEvent(r.Context(), d.DB, id)
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
