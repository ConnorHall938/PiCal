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
    
    local deps=(losetup mount wget xz)
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
    download_image
    mount_image
    
    configure_system
    configure_wifi
    
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