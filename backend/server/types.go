package server

import (
	"database/sql"
	"net/http"
)

type Server struct {
	DB         *sql.DB
	Mux        *http.ServeMux
	Fs         http.Handler
	APIDir     string
	SomfyToken string
}
