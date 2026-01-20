package server

import (
	"database/sql"
	"net/http"
)

type Server struct {
	DB  *sql.DB
	Mux *http.ServeMux
	Fs  http.Handler
}

type PagedResponse[T any] struct {
	Items  []T `json:"items"`
	Limit  int `json:"limit"`
	Offset int `json:"offset"`
	Count  int `json:"count"`
	Total  int `json:"total"`
}
