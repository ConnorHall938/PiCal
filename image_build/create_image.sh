#!/bin/bash
set -euo pipefail

# PiCal Raspberry Pi Image Builder
# Downloads and customizes Raspberry Pi OS Lite (Trixie) for Pi 5

# When running in Docker, use /workspace. Otherwise use script directory.
if [[ -d "/workspace" ]] && [[ -f "/workspace/.env" ]]; then
    BASE_DIR="/workspace"
else
    BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

WORK_DIR="${BASE_DIR}/pical-image-build"
ENV_FILE="${BASE_DIR}/.env"
OUTPUT_DIR="${BASE_DIR}/output"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Track loop device for cleanup
LOOP_DEV=""

cleanup() {
    local exit_code=$?
    log_info "Cleaning up..."
    
    # Unmount in reverse order
    local mounts=(
        "${WORK_DIR}/rootfs/dev/pts"
        "${WORK_DIR}/rootfs/dev"
        "${WORK_DIR}/rootfs/sys"
        "${WORK_DIR}/rootfs/proc"
        "${WORK_DIR}/rootfs/boot/firmware"
        "${WORK_DIR}/rootfs"
        "${WORK_DIR}/boot"
    )
    
    for mount in "${mounts[@]}"; do
        if mountpoint -q "${mount}" 2>/dev/null; then
            log_info "Unmounting ${mount}..."
            sudo umount -l "${mount}" 2>/dev/null || true
        fi
    done
    
    # Detach loop device
    if [[ -n "${LOOP_DEV:-}" ]]; then
        log_info "Detaching loop device ${LOOP_DEV}..."
        sudo losetup -d "${LOOP_DEV}" 2>/dev/null || true
    fi
    
    # CI/Pipeline safety: detach ALL loop devices associated with our work directory
    # This ensures no orphaned loop devices remain after build
    if [[ -d "${WORK_DIR}" ]]; then
        for loop in $(losetup -a 2>/dev/null | grep -F "${WORK_DIR}" | cut -d: -f1); do
            log_warn "Cleaning up orphaned loop device: ${loop}"
            sudo losetup -d "${loop}" 2>/dev/null || true
        done
    fi
    
    return $exit_code
}

trap cleanup EXIT

check_dependencies() {
    log_info "Checking dependencies..."
    
    local deps=(losetup mount wget xz git ssh-keygen openssl)
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ! -f /usr/bin/qemu-aarch64-static ]] && [[ ! -f /usr/bin/qemu-aarch64 ]]; then
        missing+=("qemu-user-static")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install with: sudo dnf install ${missing[*]}"
        exit 1
    fi
}

load_env() {
    log_info "Loading environment variables..."
    
    if [[ ! -f "${ENV_FILE}" ]]; then
        log_error "Environment file not found: ${ENV_FILE}"
        exit 1
    fi
    
    set -a
    source "${ENV_FILE}"
    set +a
    
    local required_vars=(WIFI_SSID WIFI_PASSWORD WIFI_COUNTRY ROOT_PASSWORD PICAL_PASSWORD PICAL_PORT PICAL_REPO_SSH_URL DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD DB_SSLMODE)
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Missing required variable: ${var}"
            exit 1
        fi
    done
}

download_image() {
    log_info "Downloading Raspberry Pi OS Lite (Trixie)..."
    
    mkdir -p "${WORK_DIR}"
    cd "${WORK_DIR}"
    
    local IMAGE_INDEX_URL="https://downloads.raspberrypi.com/raspios_lite_arm64/images/"
    
    log_info "Finding latest image..."
    local LATEST_DIR=$(wget -q -O - "${IMAGE_INDEX_URL}" | grep -oP 'raspios_lite_arm64-\d{4}-\d{2}-\d{2}' | sort -V | tail -1)
    
    if [[ -z "${LATEST_DIR}" ]]; then
        log_error "Could not find latest image directory"
        exit 1
    fi
    
    local IMAGE_DIR_URL="${IMAGE_INDEX_URL}${LATEST_DIR}/"
    local IMAGE_FILE=$(wget -q -O - "${IMAGE_DIR_URL}" | grep -oP '[^"]+\.img\.xz' | head -1)
    
    if [[ -z "${IMAGE_FILE}" ]]; then
        log_error "Could not find image file"
        exit 1
    fi
    
    local IMAGE_URL="${IMAGE_DIR_URL}${IMAGE_FILE}"
    local COMPRESSED_IMAGE="${WORK_DIR}/${IMAGE_FILE}"
    IMAGE_PATH="${WORK_DIR}/${IMAGE_FILE%.xz}"
    
    if [[ -f "${IMAGE_PATH}" ]]; then
        log_info "Image already exists: ${IMAGE_PATH}"
    elif [[ -f "${COMPRESSED_IMAGE}" ]]; then
        log_info "Decompressing..."
        xz -d -k "${COMPRESSED_IMAGE}"
    else
        log_info "Downloading: ${IMAGE_URL}"
        wget -c "${IMAGE_URL}" -O "${COMPRESSED_IMAGE}"
        log_info "Decompressing..."
        xz -d -k "${COMPRESSED_IMAGE}"
    fi
    
    WORK_IMAGE="${WORK_DIR}/pical-image.img"
    rm -f "${WORK_IMAGE}"
    cp "${IMAGE_PATH}" "${WORK_IMAGE}"
}

mount_image() {
    log_info "Mounting image..."
    
    LOOP_DEV=$(sudo losetup -f --show -P "${WORK_IMAGE}")
    log_info "Using loop device: ${LOOP_DEV}"
    sleep 2
    
    if [[ ! -b "${LOOP_DEV}p1" ]] || [[ ! -b "${LOOP_DEV}p2" ]]; then
        log_error "Partitions not found"
        exit 1
    fi
    
    mkdir -p "${WORK_DIR}/boot" "${WORK_DIR}/rootfs"
    
    sudo mount "${LOOP_DEV}p2" "${WORK_DIR}/rootfs"
    sudo mount "${LOOP_DEV}p1" "${WORK_DIR}/boot"
    sudo mount --bind "${WORK_DIR}/boot" "${WORK_DIR}/rootfs/boot/firmware"
    
    # Setup chroot
    sudo mount -t proc /proc "${WORK_DIR}/rootfs/proc"
    sudo mount -t sysfs /sys "${WORK_DIR}/rootfs/sys"
    sudo mount -t devtmpfs /dev "${WORK_DIR}/rootfs/dev"
    sudo mount -t devpts /dev/pts "${WORK_DIR}/rootfs/dev/pts"
    
    if [[ -f /usr/bin/qemu-aarch64-static ]]; then
        sudo cp /usr/bin/qemu-aarch64-static "${WORK_DIR}/rootfs/usr/bin/"
    else
        sudo cp /usr/bin/qemu-aarch64 "${WORK_DIR}/rootfs/usr/bin/qemu-aarch64-static"
    fi
    
    sudo cp /etc/resolv.conf "${WORK_DIR}/rootfs/etc/resolv.conf"
}

run_in_chroot() {
    sudo chroot "${WORK_DIR}/rootfs" /bin/bash -c "$1"
}

generate_ssh_key() {
    log_info "Generating SSH keypair inside image..."
    
    local ROOTFS="${WORK_DIR}/rootfs"
    
    run_in_chroot "mkdir -p /home/pical/.ssh && chmod 700 /home/pical/.ssh"
    run_in_chroot "ssh-keygen -t ed25519 -f /home/pical/.ssh/id_ed25519 -N '' -C 'pical@pical'"
    run_in_chroot "chown -R 1000:1000 /home/pical/.ssh"
    
    local PUB_KEY
    PUB_KEY=$(sudo cat "${ROOTFS}/home/pical/.ssh/id_ed25519.pub")
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN} Add this public key to your Git host:${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "${PUB_KEY}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    read -rp "Press Enter once you've added the key to continue..."
    echo ""
}

clone_repo() {
    log_info "Cloning repository into image..."
    
    local ROOTFS="${WORK_DIR}/rootfs"
    
    # Configure SSH for the git host so clone (and future pulls) work without prompts
    local GIT_HOST
    GIT_HOST=$(echo "${PICAL_REPO_SSH_URL}" | sed -n 's/.*@\([^:]*\):.*/\1/p')
    
    if [[ -n "${GIT_HOST}" ]]; then
        sudo tee "${ROOTFS}/home/pical/.ssh/config" > /dev/null << EOF
Host ${GIT_HOST}
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
EOF
        sudo chmod 600 "${ROOTFS}/home/pical/.ssh/config"
        sudo chown 1000:1000 "${ROOTFS}/home/pical/.ssh/config"
    fi
    
    # Ensure git is available in the image
    run_in_chroot "command -v git &>/dev/null || (apt-get update && apt-get install -y git)"
    
    # Clone using the in-image key
    run_in_chroot "GIT_SSH_COMMAND='ssh -i /home/pical/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new' git clone ${PICAL_REPO_SSH_URL} /opt/pical"
    run_in_chroot "chown -R 1000:1000 /opt/pical"
    
    log_info "Repository cloned successfully"
}

write_runtime_env() {
    log_info "Writing runtime environment to image..."
    
    local ROOTFS="${WORK_DIR}/rootfs"
    
    # Only runtime variables go on the Pi — build secrets (passwords, wifi creds,
    # repo URL) stay on the build host.
    sudo tee "${ROOTFS}/opt/pical/.env" > /dev/null << EOF
# PiCal runtime configuration (generated by image builder)
PICAL_PORT=${PICAL_PORT}

# Database
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_SSLMODE=${DB_SSLMODE}
EOF
    
    sudo chown 1000:1000 "${ROOTFS}/opt/pical/.env"
}

install_udev_rules() {
    log_info "Installing UDEV rules..."
    
    local ROOTFS="${WORK_DIR}/rootfs"
    
    sudo tee "${ROOTFS}/etc/udev/rules.d/99-pical-input.rules" > /dev/null << 'EOF'
# udev rules for PiCal input devices

# RPi 500 Keyboard
KERNEL=="hidraw*", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="0010", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"

# RPi 500+ Keyboard  
KERNEL=="hidraw*", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="0011", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"

# Disable HDMI CEC input devices (prevents phantom mouse cursor)
SUBSYSTEM=="input", ATTRS{name}=="vc4-hdmi-0", ENV{LIBINPUT_IGNORE_DEVICE}="1"
SUBSYSTEM=="input", ATTRS{name}=="vc4-hdmi-1", ENV{LIBINPUT_IGNORE_DEVICE}="1"

# Goodix touchscreen: map to DSI output and apply calibration matrix for 90° CCW rotation
# Calibration matrix for 90° CCW (270° CW): 0 1 0 -1 0 1
ACTION=="add|change", KERNEL=="event[0-9]*", ATTRS{name}=="*Goodix Capacitive TouchScreen*", ENV{WL_OUTPUT}="DSI-2", ENV{LIBINPUT_CALIBRATION_MATRIX}="0 1 0 -1 0 1"
EOF

    log_info "UDEV rules installed"
}

install_setup_script() {
    log_info "Installing first-boot setup script..."
    
    local ROOTFS="${WORK_DIR}/rootfs"
    
    sudo tee "${ROOTFS}/opt/pical-setup.sh" > /dev/null << 'SETUPEOF'
#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/pical-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "PiCal First Boot Setup - $(date)"
echo "=========================================="

# Load runtime config
set -a
source /opt/pical/.env
set +a

# Install dependencies
echo "[1/5] Installing packages..."

# Sync system clock before apt - the image's build date may be in the past,
# causing repo signature verification to fail ("Not live until ...")
echo "Syncing system clock..."
if command -v timedatectl &>/dev/null; then
    timedatectl set-ntp true
    # Wait for NTP sync (up to 30 seconds)
    for i in $(seq 1 30); do
        if timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q "yes"; then
            echo "Clock synced: $(date)"
            break
        fi
        sleep 1
    done
fi
# Fallback: if timedatectl didn't work, try chronyd or ntpdate
if [ "$(date +%Y)" -lt 2026 ]; then
    echo "Clock still stale, trying fallback sync..."
    chronyd -q 'server pool.ntp.org iburst' 2>/dev/null || \
    ntpdate -s pool.ntp.org 2>/dev/null || \
    echo "WARNING: Could not sync clock, apt may fail"
fi
echo "Current date: $(date)"

# Ensure Debian repos are correctly configured (chromium deps like libatk come from Debian, not RPi repo)
echo "Configuring apt sources..."

# Remove any existing Debian source configs that may be broken
rm -f /etc/apt/sources.list.d/debian.sources
sed -i '/deb.debian.org/d' /etc/apt/sources.list 2>/dev/null || true
sed -i '/debian.org\/debian/d' /etc/apt/sources.list 2>/dev/null || true

cat > /etc/apt/sources.list.d/debian.sources << EOF
Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://deb.debian.org/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

echo "Current apt sources:"
find /etc/apt/sources.list.d/ -type f -exec echo "--- {} ---" \; -exec cat {} \;
cat /etc/apt/sources.list 2>/dev/null || true

# Full update/upgrade using default repos
apt-get update
apt-get dist-upgrade -y
apt-get install -f -y
apt-get clean

apt-get install -y \
    golang \
    labwc \
    kanshi \
    wlr-randr \
    chromium \
    fonts-dejavu \
    ca-certificates \
    curl \
    gnupg

apt-get clean

# Install Node.js 25 via nvm
export HOME=/root
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
. "$HOME/.nvm/nvm.sh"
nvm install 25

# Symlink node/npm to system path so all users can access them
ln -sf "$(which node)" /usr/local/bin/node
ln -sf "$(which npm)" /usr/local/bin/npm
ln -sf "$(which npx)" /usr/local/bin/npx

apt-get clean

# Build the application
echo "[2/5] Building application..."
cd /opt/pical
git config --global --add safe.directory /opt/pical
HOME=/root make build
chmod +x /opt/pical/bin/server
chown -R pical:pical /opt/pical

# Create systemd service for the app
echo "[3/5] Creating pical service..."
cat > /etc/systemd/system/pical.service << EOF
[Unit]
Description=PiCal Server
After=network.target

[Service]
Type=simple
User=pical
WorkingDirectory=/opt/pical/bin
ExecStart=/opt/pical/bin/server
Restart=always
RestartSec=5
Environment=HOME=/home/pical

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable pical.service

# Configure kiosk mode via labwc
echo "[4/5] Configuring kiosk mode..."

# Create labwc config directory
mkdir -p /home/pical/.config/labwc
mkdir -p /home/pical/.config/kanshi

# labwc rc.xml - minimal kiosk config (no decorations, no desktop chrome)
cat > /home/pical/.config/labwc/rc.xml << 'LABWCEOF'
<?xml version="1.0"?>
<labwc_config>
  <core>
    <decoration>server</decoration>
  </core>
  <theme>
    <titlebar>
      <height>0</height>
    </titlebar>
  </theme>
  <windowRules>
    <windowRule identifier="*">
      <action name="Maximize"/>
      <skipTaskbar>yes</skipTaskbar>
    </windowRule>
  </windowRules>
</labwc_config>
LABWCEOF

# labwc autostart - poll for the host to be ready, then launch chromium
cat > /home/pical/.config/labwc/autostart << 'LABWCEOF'
#!/bin/bash

# Source runtime config so PICAL_PORT is always current
set -a
source /opt/pical/.env
set +a

PICAL_KIOSK_URL="http://localhost:${PICAL_PORT}"

# Poll until the host is actually responding (up to 120s)
echo "Waiting for ${PICAL_KIOSK_URL} ..."
for i in $(seq 1 120); do
    if curl -sf "${PICAL_KIOSK_URL}" > /dev/null 2>&1; then
        echo "Host ready after ${i}s"
        break
    fi
    sleep 1
done

# Start kanshi for output configuration (rotation)
kanshi &

# Launch chromium in kiosk mode
chromium --kiosk --noerrdialogs --disable-infobars --no-first-run \
    --enable-features=OverlayScrollbar --start-fullscreen \
    "${PICAL_KIOSK_URL}" &
LABWCEOF
chmod +x /home/pical/.config/labwc/autostart

# kanshi config - set DSI output rotation (90° CCW)
cat > /home/pical/.config/kanshi/config << 'KANSHIEOF'
profile {
    output DSI-2 mode 720x1280@60Hz position 0,0 transform 270
}
KANSHIEOF

# labwc environment - disable cursor for kiosk
cat > /home/pical/.config/labwc/environment << 'LABWCEOF'
WLR_NO_HARDWARE_CURSORS=1
LABWCEOF

chown -R pical:pical /home/pical/.config

# Create systemd service for kiosk (PAMName=login grants logind seat/input access)
# No hard dependency on pical.service — the autostart script polls the host directly
cat > /etc/systemd/system/pical-kiosk.service << EOF
[Unit]
Description=PiCal Kiosk
After=network.target

[Service]
User=pical
PAMName=login
Type=simple
TTYPath=/dev/tty1
ExecStart=/usr/bin/labwc -s /home/pical/.config/labwc/autostart
Restart=always
RestartSec=5
Environment=HOME=/home/pical

[Install]
WantedBy=graphical.target
EOF

systemctl enable pical-kiosk.service

# Disable this setup service
echo "[5/5] Finalizing..."
systemctl disable pical-first-boot.service

echo "=========================================="
echo "Setup complete! Rebooting..."
echo "=========================================="

reboot
SETUPEOF

    sudo chmod +x "${ROOTFS}/opt/pical-setup.sh"
    
    # Create first-boot service
    sudo tee "${ROOTFS}/etc/systemd/system/pical-first-boot.service" > /dev/null << 'EOF'
[Unit]
Description=PiCal First Boot Setup
After=network-online.target time-sync.target raspi-config.service
Wants=network-online.target time-sync.target
ConditionPathExists=!/var/lib/pical-setup-complete

[Service]
Type=oneshot
ExecStart=/opt/pical-setup.sh
ExecStartPost=/bin/touch /var/lib/pical-setup-complete
RemainAfterExit=yes
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOF

    run_in_chroot "systemctl enable pical-first-boot.service"
    
    log_info "Setup script installed"
}

configure_system() {
    log_info "Configuring system..."
    
    local ROOTFS="${WORK_DIR}/rootfs"
    
    # Generate password hashes
    local ROOT_HASH=$(openssl passwd -6 "${ROOT_PASSWORD}")
    local PICAL_HASH=$(openssl passwd -6 "${PICAL_PASSWORD}")
    
    # Set root password
    run_in_chroot "echo 'root:${ROOT_HASH}' | chpasswd -e"
    
    # Remove pi user if exists
    run_in_chroot "id pi &>/dev/null && userdel -r pi || true"
    
    # Create pical user
    run_in_chroot "useradd -m -s /bin/bash -G sudo,video,audio,input,gpio,i2c,spi pical"
    run_in_chroot "echo 'pical:${PICAL_HASH}' | chpasswd -e"
    
    # Passwordless sudo
    echo "pical ALL=(ALL) NOPASSWD: ALL" | sudo tee "${ROOTFS}/etc/sudoers.d/pical" > /dev/null
    sudo chmod 440 "${ROOTFS}/etc/sudoers.d/pical"
    
    # Hostname
    echo "pical" | sudo tee "${ROOTFS}/etc/hostname" > /dev/null
    sudo sed -i 's/raspberrypi/pical/g' "${ROOTFS}/etc/hosts"
    
    # Disable first-boot wizard
    run_in_chroot "systemctl disable userconfig 2>/dev/null || true"
    run_in_chroot "systemctl mask userconfig 2>/dev/null || true"
    
    # Enable SSH
    run_in_chroot "systemctl enable ssh"
    sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' "${ROOTFS}/etc/ssh/sshd_config"
}

configure_boot() {
    log_info "Configuring boot options..."
    
    local BOOT_CONFIG="${WORK_DIR}/boot/config.txt"
    
    # Disable display auto-detect so we can load the DSI overlay with rotation parameter
    sudo sed -i 's/^display_auto_detect=1/#display_auto_detect=1/' "${BOOT_CONFIG}"
    
    # Add the correct ili9881 7-inch overlay with landscape rotation (90° CCW)
    # This sets panel_orientation at the DRM level; labwc honors it natively
    if ! grep -q "vc4-kms-dsi-ili9881-7inch" "${BOOT_CONFIG}"; then
        echo "" | sudo tee -a "${BOOT_CONFIG}" > /dev/null
        echo "# DSI touchscreen landscape orientation (90° CCW)" | sudo tee -a "${BOOT_CONFIG}" > /dev/null
        echo "dtoverlay=vc4-kms-dsi-ili9881-7inch,rotation=270" | sudo tee -a "${BOOT_CONFIG}" > /dev/null
    fi
    
    # Enable USB boot with lower power supplies (allows 1.6A to USB ports)
    if ! grep -q "usb_max_current_enable" "${BOOT_CONFIG}"; then
        echo "" | sudo tee -a "${BOOT_CONFIG}" > /dev/null
        echo "# Enable USB boot with non-5A power supplies" | sudo tee -a "${BOOT_CONFIG}" > /dev/null
        echo "usb_max_current_enable=1" | sudo tee -a "${BOOT_CONFIG}" > /dev/null
    fi
    
    # Add USB storage quirks to cmdline.txt
    local CMDLINE="${WORK_DIR}/boot/cmdline.txt"
    if ! grep -q "usb-storage.quirks" "${CMDLINE}"; then
        log_info "Adding USB storage quirks to cmdline.txt..."
        sudo sed -i 's/$/ usb-storage.quirks=152d:0583:u/' "${CMDLINE}"
    fi
    
    # Add quiet boot options for faster boot
    if ! grep -q "quiet" "${CMDLINE}"; then
        log_info "Adding quiet boot options..."
        sudo sed -i 's/$/ quiet loglevel=3 systemd.show_status=auto/' "${CMDLINE}"
    fi
    
    log_info "Boot options configured"
}

configure_wifi() {
    log_info "Configuring WiFi..."
    
    local ROOTFS="${WORK_DIR}/rootfs"
    local NM_CONN_DIR="${ROOTFS}/etc/NetworkManager/system-connections"
    
    sudo mkdir -p "${NM_CONN_DIR}"
    
    # NetworkManager connection
    sudo tee "${NM_CONN_DIR}/pical-wifi.nmconnection" > /dev/null << EOF
[connection]
id=pical-wifi
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=${WIFI_SSID}

[wifi-security]
key-mgmt=wpa-psk
psk=${WIFI_PASSWORD}

[ipv4]
method=auto

[ipv6]
method=auto
EOF
    sudo chmod 600 "${NM_CONN_DIR}/pical-wifi.nmconnection"
    
    # Ensure NetworkManager has wifi enabled
    sudo mkdir -p "${ROOTFS}/var/lib/NetworkManager"
    sudo tee "${ROOTFS}/var/lib/NetworkManager/NetworkManager.state" > /dev/null << EOF
[main]
NetworkingEnabled=true
WirelessEnabled=true
WWANEnabled=true
EOF
    
    run_in_chroot "systemctl enable NetworkManager"
    
    # Set regulatory domain at boot
    sudo tee "${ROOTFS}/etc/systemd/system/wifi-country.service" > /dev/null << EOF
[Unit]
Description=Set WiFi regulatory domain
Before=NetworkManager.service

[Service]
Type=oneshot
ExecStart=/usr/sbin/iw reg set ${WIFI_COUNTRY}

[Install]
WantedBy=multi-user.target
EOF
    
    run_in_chroot "systemctl enable wifi-country.service"
}

optimize_boot() {
    log_info "Optimizing boot time..."
    
    local ROOTFS="${WORK_DIR}/rootfs"
    
    # Disable unnecessary services for a kiosk
    local DISABLE_SERVICES=(
        "apt-daily.timer"
        "apt-daily-upgrade.timer"
        "man-db.timer"
        "ModemManager.service"
        "triggerhappy.service"
        "bluetooth.service"
        "hciuart.service"
        "keyboard-setup.service"
        "rpi-eeprom-update.service"
    )
    
    for service in "${DISABLE_SERVICES[@]}"; do
        run_in_chroot "systemctl disable ${service} 2>/dev/null || true"
        run_in_chroot "systemctl mask ${service} 2>/dev/null || true"
    done
    
    # Reduce systemd default timeout (default is 90s, way too long for kiosk)
    sudo mkdir -p "${ROOTFS}/etc/systemd/system.conf.d"
    sudo tee "${ROOTFS}/etc/systemd/system.conf.d/timeout.conf" > /dev/null << 'EOF'
[Manager]
DefaultTimeoutStartSec=15s
DefaultTimeoutStopSec=10s
EOF
    
    # Disable wait for network on subsequent boots (kiosk service doesn't need it)
    # First boot still waits via pical-first-boot.service dependency
    run_in_chroot "systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true"
    
    log_info "Boot optimizations applied"
}

finalize() {
    log_info "Finalizing..."
    
    local ROOTFS="${WORK_DIR}/rootfs"
    
    sudo rm -f "${ROOTFS}/usr/bin/qemu-aarch64-static"
    sudo rm -f "${ROOTFS}/etc/resolv.conf"
    
    sync
}

main() {
    log_info "PiCal Raspberry Pi Image Builder"
    log_info "================================="
    
    check_dependencies
    load_env
    download_image
    mount_image
    
    configure_system
    generate_ssh_key
    clone_repo
    write_runtime_env
    
    configure_boot
    configure_wifi
    install_udev_rules
    install_setup_script
    optimize_boot
    
    finalize
    cleanup
    trap - EXIT
    
    mkdir -p "${OUTPUT_DIR}"
    local OUTPUT_IMAGE="${OUTPUT_DIR}/pical-$(date +%Y%m%d).img"
    mv "${WORK_IMAGE}" "${OUTPUT_IMAGE}"
    
    log_info "================================="
    log_info "Complete: ${OUTPUT_IMAGE}"
    log_info ""
    log_info "Write with: sudo dd if=${OUTPUT_IMAGE} of=/dev/sdX bs=4M conv=fsync status=progress"
    log_info "Verify with: sudo cmp -n \$(stat -c%s ${OUTPUT_IMAGE}) ${OUTPUT_IMAGE} /dev/sdX"
}

main "$@"