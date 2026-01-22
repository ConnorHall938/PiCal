#!/bin/bash
set -euo pipefail

# PiCal Raspberry Pi Image Builder
# Downloads and customizes Raspberry Pi OS Lite (Trixie) for Pi 5

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SCRIPT_DIR}/pical-image-build"
ENV_FILE="${SCRIPT_DIR}/.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

cleanup() {
    log_info "Cleaning up..."
    
    if mountpoint -q "${WORK_DIR}/rootfs/dev/pts" 2>/dev/null; then
        sudo umount "${WORK_DIR}/rootfs/dev/pts" || true
    fi
    if mountpoint -q "${WORK_DIR}/rootfs/dev" 2>/dev/null; then
        sudo umount "${WORK_DIR}/rootfs/dev" || true
    fi
    if mountpoint -q "${WORK_DIR}/rootfs/sys" 2>/dev/null; then
        sudo umount "${WORK_DIR}/rootfs/sys" || true
    fi
    if mountpoint -q "${WORK_DIR}/rootfs/proc" 2>/dev/null; then
        sudo umount "${WORK_DIR}/rootfs/proc" || true
    fi
    if mountpoint -q "${WORK_DIR}/rootfs/boot/firmware" 2>/dev/null; then
        sudo umount "${WORK_DIR}/rootfs/boot/firmware" || true
    fi
    if mountpoint -q "${WORK_DIR}/rootfs" 2>/dev/null; then
        sudo umount "${WORK_DIR}/rootfs" || true
    fi
    if mountpoint -q "${WORK_DIR}/boot" 2>/dev/null; then
        sudo umount "${WORK_DIR}/boot" || true
    fi
    
    if [[ -n "${LOOP_DEV:-}" ]]; then
        sudo losetup -d "${LOOP_DEV}" 2>/dev/null || true
    fi
}

trap cleanup EXIT

check_dependencies() {
    log_info "Checking dependencies..."
    
    local deps=(losetup mount wget xz git ssh-keygen)
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
    
    local required_vars=(WIFI_SSID WIFI_PASSWORD WIFI_COUNTRY ROOT_PASSWORD PICAL_PASSWORD)
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Missing required variable: ${var}"
            exit 1
        fi
    done
}

download_image() {
    log_info "Downloading Raspberry Pi OS Lite..."
    
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

clone_repo() {
    log_info "Cloning repository..."
    
    # Get remote URL from local repo
    local REMOTE_URL=$(git -C "${SCRIPT_DIR}" remote get-url origin)
    if [[ -z "${REMOTE_URL}" ]]; then
        log_error "Could not get remote URL from local repo"
        exit 1
    fi
    log_info "Remote URL: ${REMOTE_URL}"
    
    # Get current branch
    local CURRENT_BRANCH=$(git -C "${SCRIPT_DIR}" rev-parse --abbrev-ref HEAD)
    log_info "Current branch: ${CURRENT_BRANCH}"
    
    # Check if branch exists on remote
    if git -C "${SCRIPT_DIR}" ls-remote --heads origin "${CURRENT_BRANCH}" | grep -q "${CURRENT_BRANCH}"; then
        log_info "Branch exists on remote, cloning..."
    else
        log_warn "Branch ${CURRENT_BRANCH} not found on remote, using default branch"
        CURRENT_BRANCH=""
    fi
    
    # Clone into work directory
    local REPO_DIR="${WORK_DIR}/repo"
    rm -rf "${REPO_DIR}"
    
    if [[ -n "${CURRENT_BRANCH}" ]]; then
        git clone --depth 1 --branch "${CURRENT_BRANCH}" "${REMOTE_URL}" "${REPO_DIR}"
    else
        git clone --depth 1 "${REMOTE_URL}" "${REPO_DIR}"
    fi
    
    log_info "Repository cloned successfully"
}

generate_ssh_key() {
    log_info "Generating SSH keypair for pical user..."
    
    local SSH_DIR="${WORK_DIR}/ssh_key"
    rm -rf "${SSH_DIR}"
    mkdir -p "${SSH_DIR}"
    
    ssh-keygen -t ed25519 -f "${SSH_DIR}/id_ed25519" -N "" -C "pical@pical"
    
    SSH_PRIVATE_KEY="${SSH_DIR}/id_ed25519"
    SSH_PUBLIC_KEY="${SSH_DIR}/id_ed25519.pub"
    
    echo ""
    echo "========================================"
    echo "Add this public key to GitHub:"
    echo "========================================"
    cat "${SSH_PUBLIC_KEY}"
    echo "========================================"
    echo ""
}

install_repo_and_ssh() {
    log_info "Installing repo and SSH key into image..."
    
    local ROOTFS="${WORK_DIR}/rootfs"
    
    # Copy repo to /opt/pical
    sudo mkdir -p "${ROOTFS}/opt/pical"
    sudo cp -r "${WORK_DIR}/repo/." "${ROOTFS}/opt/pical/"
    
    # Copy .env file
    sudo cp "${ENV_FILE}" "${ROOTFS}/opt/pical/.env"
    
    sudo chown -R 1000:1000 "${ROOTFS}/opt/pical"
    
    # Install SSH key for pical user (for GitHub access)
    sudo mkdir -p "${ROOTFS}/home/pical/.ssh"
    sudo cp "${SSH_PRIVATE_KEY}" "${ROOTFS}/home/pical/.ssh/id_ed25519"
    sudo cp "${SSH_PUBLIC_KEY}" "${ROOTFS}/home/pical/.ssh/id_ed25519.pub"
    sudo chmod 700 "${ROOTFS}/home/pical/.ssh"
    sudo chmod 600 "${ROOTFS}/home/pical/.ssh/id_ed25519"
    sudo chmod 644 "${ROOTFS}/home/pical/.ssh/id_ed25519.pub"
    sudo chown -R 1000:1000 "${ROOTFS}/home/pical/.ssh"
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

# Install dependencies
echo "[1/5] Installing packages..."
apt-get update
apt-get install -y \
    golang \
    cage \
    chromium \
    fonts-dejavu \
    ca-certificates \
    curl \
    gnupg

# Install Node.js 25 via NodeSource
curl -fsSL https://deb.nodesource.com/setup_25.x | bash -
apt-get install -y nodejs

# Build the application
echo "[2/5] Building application..."
cd /opt/pical
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

# Configure kiosk mode via autologin
echo "[4/5] Configuring kiosk mode..."

# Create kiosk startup script
cat > /home/pical/kiosk.sh << 'EOF'
#!/bin/bash
# Wait for pical server to be ready
sleep 5
exec cage -s -- chromium --kiosk --noerrdialogs --disable-infobars --no-first-run --enable-features=OverlayScrollbar --start-fullscreen http://localhost:8080
EOF
chmod +x /home/pical/kiosk.sh
chown pical:pical /home/pical/kiosk.sh

# Create .bash_profile to auto-start kiosk on tty1 login
cat > /home/pical/.bash_profile << 'EOF'
if [ "$(tty)" = "/dev/tty1" ]; then
    exec /home/pical/kiosk.sh
fi
EOF
chown pical:pical /home/pical/.bash_profile

# Configure autologin on tty1
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pical --noclear %I \$TERM
EOF

systemctl enable getty@tty1

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
After=network-online.target
Wants=network-online.target
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
    clone_repo
    generate_ssh_key
    download_image
    mount_image
    
    configure_system
    configure_wifi
    install_repo_and_ssh
    install_setup_script
    
    finalize
    cleanup
    trap - EXIT
    
    local OUTPUT_IMAGE="${SCRIPT_DIR}/pical-$(date +%Y%m%d).img"
    mv "${WORK_IMAGE}" "${OUTPUT_IMAGE}"
    
    log_info "================================="
    log_info "Complete: ${OUTPUT_IMAGE}"
    log_info ""
    log_info "Write with: sudo dd if=${OUTPUT_IMAGE} of=/dev/sdX bs=4M status=progress"
}

main "$@"