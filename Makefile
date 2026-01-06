.PHONY: build dev dev-frontend dev-backend clean

# ---------- DEFAULT (production) ----------
build:
	cd frontend && npm ci && npm run build
	cd backend && go build -o ../bin/server ./cmd/server

# ---------- DEVELOPMENT ----------
dev:
	@make -j 2 dev-backend dev-frontend

dev-backend:
	cd backend && go run ./cmd/server

dev-frontend:
	cd frontend && npm run dev

# ---------- CLEAN ----------
clean:
	rm -rf bin
