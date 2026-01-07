package main

import (
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"

	"pical/database"
	"pical/server"

	"github.com/joho/godotenv"
)

func main() {

	err := godotenv.Load("../.env")
	if err != nil {
		log.Fatal("Error loading .env file")
	}

	dist, err := findFrontendDist()
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("Serving UI from: %s", dist)

	port, _ := strconv.Atoi(getenv("DB_PORT", "5432"))

	conn, err := database.Open(database.Config{
		Host:     getenv("DB_HOST", "localhost"),
		Port:     port,
		User:     getenv("DB_USER", "postgres"),
		Password: getenv("DB_PASSWORD", ""),
		Name:     getenv("DB_NAME", "postgres"),
		SSLMode:  getenv("DB_SSLMODE", "disable"),
	})
	if err != nil {
		log.Fatalf("db open: %v", err)
	}
	defer conn.Close()

	s := server.New(conn, dist)

	log.Println("listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", s.Mux))
}

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func findFrontendDist() (string, error) {
	// 0) Explicit override (handy for weird deployments)
	if v := os.Getenv("FRONTEND_DIST"); v != "" {
		p := filepath.Clean(v)
		if fileExists(filepath.Join(p, "index.html")) {
			return p, nil
		}
		return "", fmt.Errorf("FRONTEND_DIST is set but index.html not found in %q", p)
	}

	// 1) Production: relative to executable location (bin/server -> repo root)
	if exe, err := os.Executable(); err == nil {
		exeDir := filepath.Dir(exe)
		// If exe is .../bin/server then root is parent of bin
		root := filepath.Dir(exeDir)
		p := filepath.Join(root, "frontend", "dist")
		if fileExists(filepath.Join(p, "index.html")) {
			return p, nil
		}
	}

	// 2) Dev: search upwards from current working directory for frontend/dist/index.html
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	p, err := findUpwards(cwd, filepath.Join("frontend", "dist", "index.html"))
	if err == nil {
		return filepath.Dir(p), nil // return .../frontend/dist
	}

	return "", errors.New(
		"could not locate frontend dist folder.\n" +
			"Make sure you built the frontend: (cd frontend && npm run build)\n" +
			"Or set FRONTEND_DIST=/absolute/path/to/frontend/dist",
	)
}

func findUpwards(startDir, relTarget string) (string, error) {
	dir := filepath.Clean(startDir)
	for {
		candidate := filepath.Join(dir, relTarget)
		if fileExists(candidate) {
			return candidate, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("not found: %s (starting at %s)", relTarget, startDir)
		}
		dir = parent
	}
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
