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

type OccurrenceDeps struct {
	DB *sql.DB
}

func (d *OccurrenceDeps) Register(mux *http.ServeMux, wrap func(http.Handler) http.Handler) {
	mux.Handle("/occurrences", wrap(http.HandlerFunc(d.CollectionHandler)))
	mux.Handle("/occurrences/", wrap(http.HandlerFunc(d.ItemHandler)))
}

func (d *OccurrenceDeps) CollectionHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		d.getOccurrences(w, r)
	case http.MethodPost:
		d.createOccurrence(w, r)
	default:
		w.Header().Set("Allow", "GET, POST")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func (d *OccurrenceDeps) ItemHandler(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/occurrences/")
	id = strings.Trim(id, "/")

	if id == "" || strings.Contains(id, "/") {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}

	switch r.Method {
	case http.MethodGet:
		d.getOccurrence(w, r, id)
	case http.MethodDelete:
		d.deleteOccurrence(w, r, id)
	default:
		w.Header().Set("Allow", "GET, DELETE")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func (d *OccurrenceDeps) getOccurrences(w http.ResponseWriter, r *http.Request) {
	limit := utils.ParseIntQuery(r, "limit", 50, 1, 200)
	offset := utils.ParseIntQuery(r, "offset", 0, 0, 1_000_000)

	items, total, err := schemas.ListOccurrences(r.Context(), d.DB, limit, offset)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	utils.WriteJSON(w, http.StatusOK, utils.PagedResponse[schemas.Occurrence]{
		Items:  items,
		Limit:  limit,
		Offset: offset,
		Count:  len(items),
		Total:  total,
	})
}

func (d *OccurrenceDeps) createOccurrence(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()

	var in schemas.Occurrence
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	created, err := schemas.CreateOccurrence(r.Context(), d.DB, in)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	utils.WriteJSON(w, http.StatusCreated, created)
}

func (d *OccurrenceDeps) getOccurrence(w http.ResponseWriter, r *http.Request, id string) {
	out, err := schemas.GetOccurrence(r.Context(), d.DB, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "occurrence not found", http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	utils.WriteJSON(w, http.StatusOK, out)
}

func (d *OccurrenceDeps) deleteOccurrence(w http.ResponseWriter, r *http.Request, id string) {
	err := schemas.DeleteOccurrence(r.Context(), d.DB, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "occurrence not found", http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
