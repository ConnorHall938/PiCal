# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

PiCal is an electronic calendar running on a Raspberry Pi with a touchscreen display. A Go HTTP server serves both the REST API and the compiled React frontend as static files. An external PostgreSQL database is required.

## Common Commands

```bash
make              # Production build → bin/server
make dev          # Start both backend (go run) and frontend (vite dev) with hot reload
make clean        # Remove bin/

# Frontend only
cd frontend && npm run lint
cd frontend && npm run build

# Backend only
cd backend && go build -o ../bin/server .
cd backend && go run .
```

There are no test commands currently — no test files exist in this repo.

## Local Development Setup

A `compose.yaml` at the repo root (outside `pical/`) provides a PostgreSQL container. Copy `example_env` to `.env` and fill in credentials. If DB credentials change, bring the volume down first: `docker compose down -v`.

The Vite dev server (`localhost:5173`) proxies `/api/*` to the Go backend (`localhost:8080`). In production, the Go server serves the built frontend from `frontend/dist/`.

## Architecture

### Backend (`backend/`)

- `main.go` — Loads `.env`, resolves paths, opens DB, starts HTTP server, handles graceful shutdown
- `database/` — PostgreSQL connection pooling (max 25 connections, 30-min lifetime)
- `database/schemas/` — Table definitions and CRUD using a schema-builder pattern; tables are created on startup
- `server/server.go` — Routes all requests; wraps DB endpoints with a 10s timeout middleware
- `server/endpoints/` — One file per resource (`events.go`, `occurrence.go`, `blinds.go`). Each has a `*Deps` struct with `Register(mux, wrap)` that wires `CollectionHandler` (`/resource`) and `ItemHandler` (`/resource/{id}`)
- `server/utils/` — `WriteJSON`, `ParseIntQuery`, paged response helpers

**Adding a new API resource**: create `backend/server/endpoints/foo.go` with a `FooDeps` struct, implement `CollectionHandler`/`ItemHandler`, and call `Register` in `server/routes()`.

### Frontend (`frontend/src/`)

- `App.tsx` — Top-level tab switcher (Calendar / Blinds), `useReconnect()` hook for resilience
- `components/Calendar/` — Calendar view (`react-big-calendar`), event/occurrence forms, side panel
- `components/Blinds/` — Blind cards with optimistic open/close state
- `hooks/` — `useCalendarData` (fetches and transforms events + occurrences), `useBlinds`
- `api/` — Thin fetch wrappers (`fetchJSON`, `fetchAll`)
- `types/` — TypeScript interfaces for API responses and calendar data

### Data Model

- **events** — UUID, personName, title, notes, timezone, allDay, rrule (for recurring events)
- **occurrences** — UUID, eventID (FK), startTime, endTime, occurrenceKind (0=normal/1=moved/2=cancelled), newStartTime, newEndTime
- **blinds** — In-memory only (hardcoded in `endpoints/blinds.go`), not persisted

Paged list responses always return `{ items, limit, offset, count, total }`.

### API Spec

`api/openapi.yaml` is the source of truth for the REST API. It is served at `/api/` by the Go server and at `/docs` as rendered docs.

## Raspberry Pi Image Build

```bash
cd image_build && make image
```

Builds a complete flashable Pi OS image. Requires `losetup`, `mount`, `qemu-user-static`, `wget`, `xz`, `git`, `ssh-keygen`, `openssl`, and sudo. Output goes to `image_build/output/pical-<date>.img`.
