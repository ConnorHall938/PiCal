.PHONY: build dev dev-frontend dev-backend clean

# ---------- DEFAULT (production) ----------
build:
	mkdir -p bin
	cd frontend && npm ci && npm run build
	cd backend && go build -o ../bin/server ./server

# ---------- DEVELOPMENT ----------
dev:
	@make -j 2 dev-backend dev-frontend

dev-backend:
	cd backend && go run .

dev-frontend:
	cd frontend && npm run dev

# ---------- CLEAN ----------
clean:
	rm -rf bin
