# PiCal Image Builder Makefile

DOCKER_IMAGE := pical-builder
DOCKER_TAG := latest
CONTAINER_NAME := pical-build

# Directories
REPO_DIR := $(shell pwd)/..
OUTPUT_DIR := $(REPO_DIR)/output
CACHE_DIR := $(REPO_DIR)/.pical-image-build

.PHONY: help docker-build image clean clean-all

help:
	@echo "PiCal Raspberry Pi Image Builder"
	@echo ""
	@echo "Targets:"
	@echo "  docker-build  - Build the Docker image for the builder environment"
	@echo "  image         - Build the Raspberry Pi image (requires .env file)"
	@echo "  clean         - Remove build artifacts and output images"
	@echo "  clean-all     - Remove everything including Docker image and cached downloads"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - Docker with privileged container support"
	@echo "  - .env file with required variables (WIFI_SSID, WIFI_PASSWORD, etc.)"
	@echo ""
	@echo "Usage:"
	@echo "  make docker-build   # First time setup"
	@echo "  make image          # Build the Pi image"

# Build the Docker image
docker-build:
	@echo "Building Docker image: $(DOCKER_IMAGE):$(DOCKER_TAG)"
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

# Build the Docker image
docker-build-clean:
	@echo "Building Docker image: $(DOCKER_IMAGE):$(DOCKER_TAG)"
	docker build --no-cache -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

# Build the Raspberry Pi image
image: check-env
	@echo "Building Raspberry Pi image..."
	@mkdir -p $(OUTPUT_DIR)
	@mkdir -p $(CACHE_DIR)
	docker run --rm \
		--privileged \
		--name $(CONTAINER_NAME) \
		-v $(REPO_DIR):/workspace:rw \
		-v $(CACHE_DIR):/workspace/pical-image-build:rw \
		-v /dev:/dev \
		$(DOCKER_IMAGE):$(DOCKER_TAG)
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
		echo "ERROR: create_image.sh not found in repo root!"; \
		exit 1; \
	fi

# Clean build artifacts (keeps cached downloads)
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(OUTPUT_DIR)
	rm -f $(CACHE_DIR)/pical-image.img
	@echo "Done. Cached base images preserved in $(CACHE_DIR)"

# Clean everything including Docker image and cached downloads
clean-all: clean
	@echo "Removing cached downloads..."
	rm -rf $(CACHE_DIR)
	@echo "Removing Docker image..."
	docker rmi $(DOCKER_IMAGE):$(DOCKER_TAG) 2>/dev/null || true
	@echo "Done."

# CI target - builds both docker image and pi image
ci: docker-build image
	@echo "CI build complete!"