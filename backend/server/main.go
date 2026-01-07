package main

import (
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	dist, err := findFrontendDist()
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("Serving UI from: %s", dist)

	mux := http.NewServeMux()

	// API
	mux.HandleFunc("/api/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"ok": true}`))
	})

	fs := http.FileServer(http.Dir(dist))

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// Never let /api fall through to SPA
		if strings.HasPrefix(r.URL.Path, "/api/") {
			http.NotFound(w, r)
			return
		}

		// Serve real files if present
		path := filepath.Join(dist, filepath.Clean(r.URL.Path))
		if info, err := os.Stat(path); err == nil && !info.IsDir() {
			fs.ServeHTTP(w, r)
			return
		}

		// SPA fallback
		http.ServeFile(w, r, filepath.Join(dist, "index.html"))
	})

	log.Println("Listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", mux))
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
