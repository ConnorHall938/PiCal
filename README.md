# PiCal

Electronic calendar running on a Raspberry Pi with a touchscreen display.

## Architecture

### Database

An external PostgreSQL server is required. The backend connects using the following env vars (set in `.env` at the repo root):

| Variable | Default | Notes |
|---|---|---|
| `DB_HOST` | `localhost` | IP or hostname of the Postgres server |
| `DB_PORT` | `5432` | |
| `DB_NAME` | `postgres` | Database name |
| `DB_USER` | `postgres` | |
| `DB_PASSWORD` | | |
| `DB_SSLMODE` | `disable` | Valid values: `disable`, `require`, `verify-ca`, `verify-full` |

The backend creates any required tables on startup.

**Local development:** A `compose.yaml` is provided at the repo root (outside `PiCal/`) to spin up a Postgres container. The database, user, and password are initialised automatically from the compose env file on first run. If credentials change, bring the volume down first: `docker compose down -v`.

**On the Pi:** `DB_HOST` must be the IP address or mDNS hostname of the database server on your network. If using mDNS (e.g. `connorfed.local`), `avahi-daemon` must be running on the host machine. Using a static IP is more reliable.

### Backend

A Go HTTP server running on the Pi. It serves both the API and the compiled frontend as static files.

The same server is accessible from any device on the network, not just the Pi's display.

### Frontend

React/Vite UI. Built output is served by the Go backend in production.

## Building a Pi Image

A build script in `image_build/` creates a complete, ready-to-flash image.

### Prerequisites

The following must be installed on the build machine:

- `losetup`, `mount`, `wget`, `xz`, `git`, `ssh-keygen`, `openssl`
- `qemu-user-static`
- `sudo` access

### Required `.env` variables

```
# Database
# Where it is hosted
DB_HOST=
DB_PORT=5432
# Name of the database
DB_NAME=
# Login
DB_USER=
DB_PASSWORD=
# lib/pq does not support enabled
DB_SSLMODE=disable

WIFI_SSID=
WIFI_PASSWORD=
WIFI_COUNTRY=GB

# Pi Login 
ROOT_PASSWORD=
PICAL_PASSWORD=
PICAL_PORT=8080
PICAL_REPO_SSH_URL=
```

### Steps

```bash
cd image_build
make image
```

The script will:
1. Download the latest Raspberry Pi OS Lite (arm64)
2. Configure WiFi, users, hostname, and boot options
3. Generate an SSH keypair inside the image — you will be prompted to add the public key to your Git host before the repo is cloned
4. Clone the repo and write runtime config into the image
5. Install a first-boot service that installs dependencies and builds the app on first power-on

The finished image is written to `output/pical-<date>.img`. Flash with:

```bash
sudo dd if=output/pical-<date>.img of=/dev/sdX bs=4M conv=fsync status=progress
```

## Local Development

```bash
make          # Production build — output in ./bin/server
make dev      # Dev server — Go API + Vite dev server with hot reload
```

Runs the Go API alongside a Vite dev server. The frontend dev server proxies API requests to the Go backend.
