package endpoints

import (
	"encoding/json"
	"net/http"
	"strings"
	"sync"
)

type Blind struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	IsOpen bool   `json:"isOpen"`
}

type BlindsDeps struct {
	mu     sync.Mutex
	blinds []Blind
}

func NewBlindsDeps() *BlindsDeps {
	return &BlindsDeps{
		blinds: []Blind{
			{ID: "blind-1", Name: "Living Room", IsOpen: false},
			{ID: "blind-2", Name: "Bedroom", IsOpen: true},
			{ID: "blind-3", Name: "Kitchen", IsOpen: false},
		},
	}
}

func (d *BlindsDeps) Register(mux *http.ServeMux, wrap func(http.Handler) http.Handler) {
	mux.Handle("/blinds", wrap(http.HandlerFunc(d.CollectionHandler)))
	mux.Handle("/blinds/", wrap(http.HandlerFunc(d.ItemHandler)))
}

func (d *BlindsDeps) CollectionHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.Header().Set("Allow", "GET")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	d.mu.Lock()
	out := make([]Blind, len(d.blinds))
	copy(out, d.blinds)
	d.mu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(out)
}

func (d *BlindsDeps) ItemHandler(w http.ResponseWriter, r *http.Request) {
	// Path: /blinds/{id} or /blinds/{id}/open or /blinds/{id}/close
	rest := strings.TrimPrefix(r.URL.Path, "/blinds/")
	rest = strings.Trim(rest, "/")
	if rest == "" {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}

	parts := strings.SplitN(rest, "/", 2)
	id := parts[0]
	action := ""
	if len(parts) == 2 {
		action = parts[1]
	}

	switch {
	case action == "" && r.Method == http.MethodGet:
		d.getBlind(w, id)
	case action == "open" && r.Method == http.MethodPost:
		d.setBlind(w, id, true)
	case action == "close" && r.Method == http.MethodPost:
		d.setBlind(w, id, false)
	default:
		http.Error(w, "not found", http.StatusNotFound)
	}
}

func (d *BlindsDeps) getBlind(w http.ResponseWriter, id string) {
	d.mu.Lock()
	defer d.mu.Unlock()
	for _, b := range d.blinds {
		if b.ID == id {
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(b)
			return
		}
	}
	http.Error(w, "blind not found", http.StatusNotFound)
}

func (d *BlindsDeps) setBlind(w http.ResponseWriter, id string, open bool) {
	d.mu.Lock()
	defer d.mu.Unlock()
	for i, b := range d.blinds {
		if b.ID == id {
			d.blinds[i].IsOpen = open
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(d.blinds[i])
			return
		}
	}
	http.Error(w, "blind not found", http.StatusNotFound)
}
