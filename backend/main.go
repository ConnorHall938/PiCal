package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"syscall"
	"time"

	"pical/database"
	"pical/server"

	"github.com/joho/godotenv"
)

func main() {
	// Root lifetime context: canceled on SIGINT/SIGTERM
	rootCtx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

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

	s, err := server.New(rootCtx, conn, dist)
	if err != nil {
		log.Fatalf("Failed to create server! %v", err)
	}

	httpSrv := &http.Server{
		Addr:    ":8080",
		Handler: s.Mux,
	}

	// Run server in background
	go func() {
		log.Println("listening on :8080")
		if err := httpSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	// Wait for shutdown signal
	<-rootCtx.Done()
	log.Println("shutdown signal received")

	// Graceful shutdown (finish inflight requests)
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := httpSrv.Shutdown(shutdownCtx); err != nil {
		log.Printf("http shutdown error: %v", err)
	}

	log.Println("shutdown complete")
}

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

// Finding the frontend directory

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
