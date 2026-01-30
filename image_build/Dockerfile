# PiCal Raspberry Pi Image Builder
# Fedora-based container for building custom Pi images

FROM fedora:40

LABEL maintainer="pical"
LABEL description="Build environment for PiCal Raspberry Pi images"

# Install dependencies
RUN dnf install -y \
    util-linux \
    wget \
    xz \
    git \
    openssh-clients \
    openssl \
    qemu-user-static \
    procps-ng \
    findutils \
    rsync \
    && dnf clean all

# Register binfmt for aarch64 (allows running ARM binaries via QEMU)
# This may already be handled by the host if running privileged
RUN mkdir -p /lib/binfmt.d

# Create working directory
WORKDIR /workspace

# Entrypoint script that ensures cleanup of loop devices
COPY <<'EOF' /usr/local/bin/entrypoint.sh
#!/bin/bash
set -e

echo "=== PiCal Image Builder ==="
echo "Workspace: /workspace"

# Function to cleanup all loop devices associated with workspace
cleanup_loops() {
    echo "Cleaning up any loop devices..."
    for loop in $(losetup -a 2>/dev/null | grep -F "/workspace" | cut -d: -f1); do
        echo "Detaching orphaned loop device: ${loop}"
        losetup -d "${loop}" 2>/dev/null || true
    done
}

# Cleanup any existing loop devices from previous failed runs
cleanup_loops

# Verify build script exists
if [[ ! -f "/workspace/image_build/create_image.sh" ]]; then
    echo "ERROR: image_build/create_image.sh not found in /workspace"
    echo "Make sure the repository is mounted correctly"
    exit 1
fi

# Run the build
cd /workspace
chmod +x /workspace/image_build/create_image.sh
/workspace/image_build/create_image.sh "$@"
exit_code=$?

# Final cleanup
cleanup_loops

exit $exit_code
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]