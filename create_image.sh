#!/bin/bash
#
# setup-pi-image.sh
#
# Downloads a Raspberry Pi OS image and customizes it for PiCal kiosk deployment.
# Must be run as root (or with sudo) because it mounts disk images.
#
# Usage:
#   sudo ./setup-pi-image.sh
#
# Prerequisites:
#   - .env file in the same directory (copy from .env.template)
#   - Run from the root of your PiCal repository
#
set -euo pipefail

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(pwd)"
WORK_DIR="${SCRIPT_DIR}/build"
ENV_FILE="${SCRIPT_DIR}/.env"

# Raspberry Pi OS Lite 64-bit (Bookworm) - Pi 5 compatible
IMAGE_URL="https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2024-11-19/2024-11-19-raspios-bookworm-arm64-lite.img.xz"
IMAGE_FILENAME="raspios-bookworm-arm64-lite.img.xz"
IMAGE_NAME="raspios-bookworm-arm64-lite.img"
OUTPUT_IMAGE="pical-image.img"

#------------------------------------------------------------------------------
# Colors for output
#------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#------------------------------------------------------------------------------
# Cleanup function - ensures mounts are released on exit
#------------------------------------------------------------------------------
cleanup() {
    log_info "Cleaning up..."
    
    # Unmount if still mounted
    if mountpoint -q "${WORK_DIR}/rootfs" 2>/dev/null; then
        umount "${WORK_DIR}/rootfs" || true
    fi
    if mountpoint -q "${WORK_DIR}/boot" 2>/dev/null; then
        umount "${WORK_DIR}/boot" || true
    fi
    
    # Detach loop device
    if [[ -n "${LOOP_DEV:-}" ]]; then
        losetup -d "${LOOP_DEV}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

#------------------------------------------------------------------------------
# Check prerequisites
#------------------------------------------------------------------------------
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Must be root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Check for required tools
    local required_tools=("wget" "xz" "losetup" "mount" "openssl" "parted")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_error "Required tool not found: $tool"
            exit 1
        fi
    done
    
    # Check for .env file
    if [[ ! -f "${ENV_FILE}" ]]; then
        log_error ".env file not found at ${ENV_FILE}"
        log_error "Copy .env.template to .env and fill in your values"
        exit 1
    fi
    
    # Check we're in a repo (has some indication of being PiCal)
    if [[ ! -d "${REPO_ROOT}" ]]; then
        log_error "Repository root not found. Run this script from your PiCal repo root."
        exit 1
    fi
    
    log_info "Prerequisites OK"
}

#------------------------------------------------------------------------------
# Load environment variables
#------------------------------------------------------------------------------
load_env() {
    log_info "Loading environment variables..."
    
    # Source the .env file
    set -a
    source "${ENV_FILE}"
    set +a
    
    # Validate required variables
    local required_vars=("WIFI_SSID" "WIFI_PASSWORD" "WIFI_COUNTRY" "ROOT_PASSWORD")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required variable ${var} not set in .env"
            exit 1
        fi
    done
    
    # Set defaults for optional variables
    PI_HOSTNAME="${PI_HOSTNAME:-pical}"
    
    log_info "Environment loaded (hostname: ${PI_HOSTNAME})"
}

#------------------------------------------------------------------------------
# Download the Raspberry Pi OS image
#------------------------------------------------------------------------------
download_image() {
    mkdir -p "${WORK_DIR}"
    
    if [[ -f "${WORK_DIR}/${IMAGE_NAME}" ]]; then
        log_info "Image already exists, skipping download"
        return
    fi
    
    log_info "Downloading Raspberry Pi OS image..."
    wget -O "${WORK_DIR}/${IMAGE_FILENAME}" "${IMAGE_URL}"
    
    log_info "Extracting image..."
    xz -dk "${WORK_DIR}/${IMAGE_FILENAME}"
    
    # Find the extracted image (name may vary slightly)
    local extracted=$(find "${WORK_DIR}" -name "*.img" -type f | head -1)
    if [[ -n "$extracted" && "$extracted" != "${WORK_DIR}/${IMAGE_NAME}" ]]; then
        mv "$extracted" "${WORK_DIR}/${IMAGE_NAME}"
    fi
    
    log_info "Image ready: ${WORK_DIR}/${IMAGE_NAME}"
}

#------------------------------------------------------------------------------
# Mount the image partitions
#------------------------------------------------------------------------------
mount_image() {
    log_info "Setting up loop device and mounting partitions..."
    
    # Create a working copy of the image
    cp "${WORK_DIR}/${IMAGE_NAME}" "${WORK_DIR}/${OUTPUT_IMAGE}"
    
    # Set up loop device with partition scanning
    LOOP_DEV=$(losetup -fP --show "${WORK_DIR}/${OUTPUT_IMAGE}")
    log_info "Loop device: ${LOOP_DEV}"
    
    # Wait for partition devices to appear
    sleep 2
    
    # Create mount points
    mkdir -p "${WORK_DIR}/boot"
    mkdir -p "${WORK_DIR}/rootfs"
    
    # Mount partitions (p1 = boot, p2 = rootfs)
    mount "${LOOP_DEV}p1" "${WORK_DIR}/boot"
    mount "${LOOP_DEV}p2" "${WORK_DIR}/rootfs"
    
    log_info "Partitions mounted"
}

#------------------------------------------------------------------------------
# Configure WiFi (NetworkManager for Bookworm)
#------------------------------------------------------------------------------
configure_wifi() {
    log_info "Configuring WiFi..."
    
    local nm_dir="${WORK_DIR}/rootfs/etc/NetworkManager/system-connections"
    mkdir -p "${nm_dir}"
    
    # Create NetworkManager connection file
    cat > "${nm_dir}/wifi.nmconnection" << EOF
[connection]
id=${WIFI_SSID}
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=${WIFI_SSID}

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=${WIFI_PASSWORD}

[ipv4]
method=auto

[ipv6]
method=auto
EOF
    
    # Set correct permissions (NetworkManager requires 600)
    chmod 600 "${nm_dir}/wifi.nmconnection"
    
    # Set WiFi country in boot config
    echo "country=${WIFI_COUNTRY}" >> "${WORK_DIR}/boot/config.txt"
    
    log_info "WiFi configured for SSID: ${WIFI_SSID}"
}

#------------------------------------------------------------------------------
# Set root password
#------------------------------------------------------------------------------
set_root_password() {
    log_info "Setting root password..."
    
    # Generate password hash
    local pass_hash=$(openssl passwd -6 "${ROOT_PASSWORD}")
    
    # Update root's password in /etc/shadow
    sed -i "s|^root:[^:]*:|root:${pass_hash}:|" "${WORK_DIR}/rootfs/etc/shadow"
    
    # Enable root login (optional, for emergency access)
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' "${WORK_DIR}/rootfs/etc/ssh/sshd_config" 2>/dev/null || true
    
    log_info "Root password set"
}

#------------------------------------------------------------------------------
# Disable first-boot setup wizard
#------------------------------------------------------------------------------
disable_first_boot_wizard() {
    log_info "Disabling first-boot setup wizard..."
    
    # Remove the userconf service that forces user creation
    rm -f "${WORK_DIR}/rootfs/etc/systemd/system/multi-user.target.wants/userconfig.service" 2>/dev/null || true
    rm -f "${WORK_DIR}/rootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf" 2>/dev/null || true
    
    # Disable piwiz (the graphical setup wizard)
    rm -f "${WORK_DIR}/rootfs/etc/xdg/autostart/piwiz.desktop" 2>/dev/null || true
    
    # Create a default user 'pi' to prevent userconf from running
    # This also allows autologin for kiosk mode
    local pi_pass_hash=$(openssl passwd -6 "raspberry")
    
    # Check if pi user already exists in passwd
    if ! grep -q "^pi:" "${WORK_DIR}/rootfs/etc/passwd"; then
        echo "pi:x:1000:1000:,,,:/home/pi:/bin/bash" >> "${WORK_DIR}/rootfs/etc/passwd"
        echo "pi:${pi_pass_hash}:19000:0:99999:7:::" >> "${WORK_DIR}/rootfs/etc/shadow"
        echo "pi:x:1000:" >> "${WORK_DIR}/rootfs/etc/group"
        mkdir -p "${WORK_DIR}/rootfs/home/pi"
        chown 1000:1000 "${WORK_DIR}/rootfs/home/pi"
    fi
    
    # Add pi to necessary groups
    for group in sudo video audio input render; do
        if grep -q "^${group}:" "${WORK_DIR}/rootfs/etc/group"; then
            sed -i "/^${group}:/s/$/,pi/" "${WORK_DIR}/rootfs/etc/group"
            sed -i "s/,pi,pi/,pi/g" "${WORK_DIR}/rootfs/etc/group"  # Fix double entries
            sed -i "s/:,pi/:pi/g" "${WORK_DIR}/rootfs/etc/group"    # Fix leading comma
        fi
    done
    
    # Mark system as configured
    touch "${WORK_DIR}/boot/firstrun.sh.done"
    
    log_info "First-boot wizard disabled, default user 'pi' created"
}

#------------------------------------------------------------------------------
# Set hostname
#------------------------------------------------------------------------------
set_hostname() {
    log_info "Setting hostname to ${PI_HOSTNAME}..."
    
    echo "${PI_HOSTNAME}" > "${WORK_DIR}/rootfs/etc/hostname"
    sed -i "s/raspberrypi/${PI_HOSTNAME}/g" "${WORK_DIR}/rootfs/etc/hosts"
    
    log_info "Hostname set"
}

#------------------------------------------------------------------------------
# Copy repository to /opt/PiCal
#------------------------------------------------------------------------------
copy_repository() {
    log_info "Copying repository to /opt/PiCal..."
    
    local target="${WORK_DIR}/rootfs/opt/PiCal"
    mkdir -p "${target}"
    
    # Copy everything except build artifacts and this script's working directory
    rsync -a \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='build' \
        --exclude='*.img' \
        --exclude='*.img.xz' \
        "${REPO_ROOT}/" "${target}/"
    
    # Ensure bin directory exists for the Go binary
    mkdir -p "${target}/bin"
    
    # Set ownership (will be pi:pi, uid 1000)
    chown -R 1000:1000 "${target}"
    
    log_info "Repository copied to /opt/PiCal"
}

#------------------------------------------------------------------------------
# Create first-boot script for installing dependencies
# (We can't run apt inside a mounted image - different architecture)
#------------------------------------------------------------------------------
create_first_boot_setup() {
    log_info "Creating first-boot setup script..."
    
    cat > "${WORK_DIR}/rootfs/opt/PiCal/first-boot-setup.sh" << 'FIRSTBOOT'
#!/bin/bash
#
# First-boot setup script for PiCal
# This runs once on first boot to install dependencies
#
set -euo pipefail

LOG_FILE="/var/log/pical-first-boot.log"
MARKER_FILE="/opt/PiCal/.first-boot-complete"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "=========================================="
echo "PiCal First Boot Setup - $(date)"
echo "=========================================="

# Skip if already completed
if [[ -f "${MARKER_FILE}" ]]; then
    echo "First boot setup already completed, skipping"
    exit 0
fi

# Wait for network
echo "Waiting for network..."
for i in {1..30}; do
    if ping -c 1 google.com &>/dev/null; then
        echo "Network is up"
        break
    fi
    sleep 2
done

# Update package list
echo "Updating package list..."
apt-get update

# Install Go (for building/running the server)
echo "Installing Go..."
apt-get install -y golang

# Install Node.js and npm (for frontend dependencies)
echo "Installing Node.js..."
apt-get install -y nodejs npm

# Install kiosk dependencies
# cage: minimal Wayland compositor for kiosk mode
# chromium-browser: web browser for displaying the UI
echo "Installing kiosk dependencies..."
apt-get install -y cage chromium-browser

# Install any additional tools that might be useful
apt-get install -y git

# Install Node dependencies if package.json exists
if [[ -f /opt/PiCal/package.json ]]; then
    echo "Installing Node dependencies..."
    cd /opt/PiCal
    npm install --production
fi

# Build Go application if main.go exists and binary doesn't
if [[ -f /opt/PiCal/main.go || -f /opt/PiCal/cmd/server/main.go ]]; then
    if [[ ! -f /opt/PiCal/bin/server ]]; then
        echo "Building Go application..."
        cd /opt/PiCal
        
        # Try common project structures
        if [[ -f cmd/server/main.go ]]; then
            go build -o bin/server ./cmd/server
        elif [[ -f main.go ]]; then
            go build -o bin/server .
        fi
    fi
fi

# Enable the services we created
systemctl daemon-reload
systemctl enable pical-server.service
systemctl enable pical-kiosk.service

# Start services
systemctl start pical-server.service
# Kiosk will start on next boot (needs graphical target)

# Mark first boot as complete
touch "${MARKER_FILE}"

echo "=========================================="
echo "First boot setup complete!"
echo "Rebooting to apply all changes..."
echo "=========================================="

reboot
FIRSTBOOT

    chmod +x "${WORK_DIR}/rootfs/opt/PiCal/first-boot-setup.sh"
    
    # Create systemd service for first boot
    cat > "${WORK_DIR}/rootfs/etc/systemd/system/pical-first-boot.service" << 'EOF'
[Unit]
Description=PiCal First Boot Setup
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/opt/PiCal/.first-boot-complete

[Service]
Type=oneshot
ExecStart=/opt/PiCal/first-boot-setup.sh
RemainAfterExit=yes
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOF

    # Enable the first boot service
    ln -sf /etc/systemd/system/pical-first-boot.service \
        "${WORK_DIR}/rootfs/etc/systemd/system/multi-user.target.wants/pical-first-boot.service"
    
    log_info "First-boot setup script created"
}

#------------------------------------------------------------------------------
# Create the PiCal server systemd service
#------------------------------------------------------------------------------
create_server_service() {
    log_info "Creating PiCal server service..."
    
    cat > "${WORK_DIR}/rootfs/etc/systemd/system/pical-server.service" << 'EOF'
[Unit]
Description=PiCal Go Server
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/opt/PiCal
ExecStart=/opt/PiCal/bin/server
Restart=always
RestartSec=5
Environment=HOME=/home/pi

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=pical-server

[Install]
WantedBy=multi-user.target
EOF

    log_info "Server service created"
}

#------------------------------------------------------------------------------
# Create the kiosk mode service
#------------------------------------------------------------------------------
create_kiosk_service() {
    log_info "Creating kiosk mode service..."
    
    # Create a script that launches the kiosk
    cat > "${WORK_DIR}/rootfs/opt/PiCal/start-kiosk.sh" << 'EOF'
#!/bin/bash
#
# Start kiosk mode using cage (Wayland compositor) and Chromium
#

# Wait for the server to be ready
echo "Waiting for PiCal server..."
for i in {1..30}; do
    if curl -s http://localhost:8080/ > /dev/null 2>&1; then
        echo "Server is ready"
        break
    fi
    sleep 1
done

# Launch Chromium in kiosk mode inside cage
# --kiosk: fullscreen, no UI elements
# --noerrdialogs: suppress error dialogs
# --disable-infobars: hide info bars
# --disable-session-crashed-bubble: don't show crash recovery
# --disable-features=TranslateUI: disable translation popup
exec cage -- chromium-browser \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-features=TranslateUI \
    --check-for-update-interval=31536000 \
    --disable-component-update \
    --autoplay-policy=no-user-gesture-required \
    http://localhost:8080/
EOF

    chmod +x "${WORK_DIR}/rootfs/opt/PiCal/start-kiosk.sh"
    
    # Create systemd service for kiosk
    cat > "${WORK_DIR}/rootfs/etc/systemd/system/pical-kiosk.service" << 'EOF'
[Unit]
Description=PiCal Kiosk Display
After=pical-server.service
Wants=pical-server.service

[Service]
Type=simple
User=pi
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=WLR_LIBINPUT_NO_DEVICES=1
ExecStartPre=/bin/sleep 5
ExecStart=/opt/PiCal/start-kiosk.sh
Restart=always
RestartSec=10

# GPU access
SupplementaryGroups=video render input

[Install]
WantedBy=graphical.target
EOF

    # Create the runtime directory structure
    mkdir -p "${WORK_DIR}/rootfs/run/user"
    
    # Ensure graphical target is default (for kiosk)
    ln -sf /lib/systemd/system/graphical.target \
        "${WORK_DIR}/rootfs/etc/systemd/system/default.target" 2>/dev/null || true
    
    log_info "Kiosk service created"
}

#------------------------------------------------------------------------------
# Enable SSH for remote access
#------------------------------------------------------------------------------
enable_ssh() {
    log_info "Enabling SSH..."
    
    # Create the ssh file in boot partition to enable SSH
    touch "${WORK_DIR}/boot/ssh"
    
    # Also enable via systemd
    ln -sf /lib/systemd/system/ssh.service \
        "${WORK_DIR}/rootfs/etc/systemd/system/multi-user.target.wants/ssh.service" 2>/dev/null || true
    
    log_info "SSH enabled"
}

#------------------------------------------------------------------------------
# Finalize and unmount
#------------------------------------------------------------------------------
finalize() {
    log_info "Finalizing image..."
    
    # Sync filesystem
    sync
    
    # Unmount partitions
    umount "${WORK_DIR}/boot"
    umount "${WORK_DIR}/rootfs"
    
    # Detach loop device
    losetup -d "${LOOP_DEV}"
    unset LOOP_DEV  # Prevent cleanup from trying again
    
    # Move final image to script directory
    mv "${WORK_DIR}/${OUTPUT_IMAGE}" "${SCRIPT_DIR}/${OUTPUT_IMAGE}"
    
    log_info "=========================================="
    log_info "Image created successfully!"
    log_info "Output: ${SCRIPT_DIR}/${OUTPUT_IMAGE}"
    log_info "=========================================="
    log_info ""
    log_info "To flash the image to an SD card:"
    log_info "  sudo dd if=${SCRIPT_DIR}/${OUTPUT_IMAGE} of=/dev/sdX bs=4M status=progress"
    log_info ""
    log_info "Or use Raspberry Pi Imager and select 'Use custom' image"
    log_info ""
    log_info "Default credentials:"
    log_info "  User: pi / Password: raspberry"
    log_info "  Root: root / Password: (from your .env)"
    log_info ""
    log_info "On first boot, the Pi will:"
    log_info "  1. Connect to WiFi (${WIFI_SSID})"
    log_info "  2. Install Go, Node.js, and kiosk dependencies"
    log_info "  3. Build the Go application (if needed)"
    log_info "  4. Reboot and start the kiosk"
    log_info "=========================================="
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------
main() {
    echo "=========================================="
    echo "PiCal Raspberry Pi Image Builder"
    echo "=========================================="
    
    check_prerequisites
    load_env
    download_image
    mount_image
    configure_wifi
    set_root_password
    disable_first_boot_wizard
    set_hostname
    enable_ssh
    copy_repository
    create_first_boot_setup
    create_server_service
    create_kiosk_service
    finalize
}

main "$@"