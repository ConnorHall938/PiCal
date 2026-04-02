# PiCal Image Builder Makefile

# Directories
REPO_DIR := $(shell pwd)/..
OUTPUT_DIR := $(REPO_DIR)/output
WORK_DIR := $(REPO_DIR)/pical-image-build

.PHONY: help image clean

help:
	@echo "PiCal Raspberry Pi Image Builder"
	@echo ""
	@echo "Targets:"
	@echo "  image  - Build the Raspberry Pi image (requires .env file)"
	@echo "  clean  - Remove build artifacts and output images"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - losetup, mount, wget, xz, git, ssh-keygen, openssl, qemu-user-static"
	@echo "  - sudo access"
	@echo "  - .env file with required variables (WIFI_SSID, WIFI_PASSWORD, etc.)"
	@echo ""
	@echo "Usage:"
	@echo "  make image  # Build the Pi image"

# Build the Raspberry Pi image
image: check-env
	@echo "Building Raspberry Pi image..."
	@mkdir -p $(OUTPUT_DIR)
	@mkdir -p $(WORK_DIR)
	$(REPO_DIR)/image_build/create_image.sh
	@echo ""
	@echo "Image built successfully!"
	@echo "Output: $(OUTPUT_DIR)/"
	@ls -lh $(OUTPUT_DIR)/*.img 2>/dev/null || true

# Check that required files exist
check-env:
	@if [ ! -f "$(REPO_DIR)/.env" ]; then \
		echo "ERROR: .env file not found!"; \
		echo "Create a .env file with:"; \
		echo "  WIFI_SSID=your_wifi"; \
		echo "  WIFI_PASSWORD=your_password"; \
		echo "  WIFI_COUNTRY=US"; \
		echo "  ROOT_PASSWORD=your_root_password"; \
		echo "  PICAL_PASSWORD=your_pical_password"; \
		exit 1; \
	fi
	@if [ ! -f "$(REPO_DIR)/image_build/create_image.sh" ]; then \
		echo "ERROR: create_image.sh not found!"; \
		exit 1; \
	fi

# Clean build artifacts and output images
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(OUTPUT_DIR)
	rm -rf $(WORK_DIR)
	@echo "Done."
