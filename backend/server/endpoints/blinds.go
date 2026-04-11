package endpoints

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"pical/server/utils"
	"strings"
)

type somfyBlind struct {
	ID               string `json:"deviceURL"`
	Name             string `json:"label"`
	ControllableName string `json:"controllableName"`
}

type Blind struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type BlindsDeps struct {
	somfyToken string
	somfyHost  string
	somfyID    string
	tokenEmpty bool
}

func (d *BlindsDeps) fetchFromSomfy(ctx context.Context) ([]Blind, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, d.somfyHost+"/setup/devices", nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+d.somfyToken)
	req.Header.Set("Accept", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("somfy API returned %d", resp.StatusCode)
	}

	var result []somfyBlind
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	var blinds []Blind
	for _, blind := range result {
		if blind.ControllableName == "rts:BlindRTSComponent" {
			id := strings.TrimPrefix(blind.ID, "rts://")
			id = strings.TrimPrefix(id, d.somfyID+"/")
			blinds = append(blinds, Blind{
				ID:   id,
				Name: blind.Name,
			})
		}
	}
	return blinds, nil
}

func (d *BlindsDeps) Register(mux *http.ServeMux, wrap func(http.Handler) http.Handler) {

	token, ok := os.LookupEnv("SOMFY_TOKEN")
	endpoint := os.Getenv("SOMFY_ENDPOINT")

	if endpoint == "" {
		d.tokenEmpty = true
	} else {
		d.somfyHost = endpoint
		s := strings.TrimPrefix(endpoint, "https://gateway-")
		s = strings.Split(s, ".local")[0]
		d.somfyID = s
	}

	switch {
	case !ok:
		mux.Handle("/blinds", wrap(http.HandlerFunc(d.NotRegisteredHandler)))
		return
	case token == "":
		// Set but empty — register routes but return an error
		d.tokenEmpty = true
		fallthrough
	default:
		// Set with a value — register routes normally
		d.somfyToken = token
	}

	mux.Handle("/blinds", wrap(http.HandlerFunc(d.CollectionHandler)))
	mux.Handle("/blinds/", wrap(http.HandlerFunc(d.ItemHandler)))
}

func (d *BlindsDeps) NotRegisteredHandler(w http.ResponseWriter, r *http.Request) {
	print("Fuck")
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusServiceUnavailable)
	json.NewEncoder(w).Encode(map[string]string{
		"error": "Module not available: API token or endpoint not configured",
	})
}

func (d *BlindsDeps) CollectionHandler(w http.ResponseWriter, r *http.Request) {
	if d.tokenEmpty {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{
			"error": "API token not configured",
		})
		return
	}

	if r.Method != http.MethodGet {
		w.Header().Set("Allow", "GET")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	somfyBlinds, err := d.fetchFromSomfy(r.Context())
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	utils.WriteJSON(w, http.StatusOK, somfyBlinds)
}

func (d *BlindsDeps) ItemHandler(w http.ResponseWriter, r *http.Request) {
	if d.tokenEmpty {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{
			"error": "API token not configured",
		})
		return
	}

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
	case action == "open" && r.Method == http.MethodPost:
		d.setBlind(w, r, id, true)
	case action == "close" && r.Method == http.MethodPost:
		d.setBlind(w, r, id, false)
	default:
		http.Error(w, "not found", http.StatusNotFound)
	}
}

func (d *BlindsDeps) setBlind(w http.ResponseWriter, r *http.Request, id string, open bool) {
	commandName := "close"
	if open {
		commandName = "open"
	}

	type command struct {
		Name string `json:"name"`
	}
	type action struct {
		DeviceURL string    `json:"deviceURL"`
		Commands  []command `json:"commands"`
	}
	type requestBody struct {
		Actions []action `json:"actions"`
	}

	data, err := json.Marshal(requestBody{[]action{{
		DeviceURL: "rts://" + d.somfyID + "/" + id,
		Commands:  []command{{Name: commandName}},
	}}})
	if err != nil {
		http.Error(w, "Failed to build request", http.StatusInternalServerError)
		return
	}

	req, err := http.NewRequestWithContext(r.Context(), http.MethodPost, d.somfyHost+"/exec/apply", bytes.NewBuffer(data))
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}
	req.Header.Set("Authorization", "Bearer "+d.somfyToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		http.Error(w, "Failed to contact Somfy", http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		http.Error(w, "Somfy returned an error", http.StatusBadGateway)
		return
	}

	w.WriteHeader(http.StatusOK)
}
