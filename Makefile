SHELL := /bin/sh
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables

OUTPUT_DIR := ./output
OVERLAY_DIR := ./overlay
BUILD_DIR := ./build
SCRIPTS_DIR := ./scripts

GO := /tmp/go/bin/go

.PHONY: all iso rpi clean distclean docker shell checksums sign
.PHONY: install-local distro-tarball publish-cgp docker-release release deps

all: iso rpi checksums sign

iso: install-local
	@echo "==> Building x86_64 ISO..."
	@bash $(SCRIPTS_DIR)/build-image.sh --profile x86_64

rpi: install-local
	@echo "==> Building aarch64 RPi image..."
	@bash $(SCRIPTS_DIR)/build-image.sh --profile aarch64

clean:
	@echo "==> Cleaning build artifacts..."
	rm -rf $(BUILD_DIR) $(OUTPUT_DIR)
	rm -f *.iso *.img *.tar.gz
	@echo "  done."

distclean: clean
	@echo "==> Removing build cache..."
	rm -rf ./cache ./work
	@echo "  done."

docker:
	@echo "==> Building Docker build image..."
	docker build -f docker/Dockerfile.build -t cognitiveos-builder .
	@echo "  done."

shell:
	@echo "==> Starting interactive shell in build container..."
	docker run --rm -it \
		-v "$(CURDIR)/../cpm:/src/cpm" \
		-v "$(CURDIR)/../cognitiveosd:/src/cognitiveosd" \
		-v "$(CURDIR)/../cli:/src/cli" \
		-v "$(CURDIR)/../inference:/src/inference" \
		-v "$(CURDIR)/../core-mcp-bridges:/src/core-mcp-bridges" \
		-w /workspace \
		cognitiveos-builder /bin/sh

checksums:
	@echo "==> Generating checksums..."
	@bash $(SCRIPTS_DIR)/sign.sh

sign: checksums
	@echo "  done."

install-local: deps
	@echo "==> Building all binaries from local source..."
	bash $(SCRIPTS_DIR)/build-binaries.sh
	@echo "==> Building overlay..."
	bash $(SCRIPTS_DIR)/build-overlay.sh
	@echo "  done."

distro-tarball: install-local
	@echo "==> Building distro tarball..."
	bash $(SCRIPTS_DIR)/build-distro-tarball.sh
	@echo "  done."

publish-cgp:
	@echo "==> Publishing .cgp packages to registry..."
	@if [ -z "$${REGISTRY_TOKEN}" ]; then \
		echo "  ERROR: REGISTRY_TOKEN not set"; exit 1; \
	fi
	@VERSION=$$(git describe --tags --abbrev=0 2>/dev/null || echo "dev")
	@for bin in $(BUILD_DIR)/bin/*; do \
		name=$$(basename "$$bin"); \
		[ "$$name" = "bridges" ] && continue; \
		bash $(SCRIPTS_DIR)/publish-cgp.sh --name "$$name" --version "$$VERSION" --binary "$$bin"; \
	done
	@echo "  done."

docker-release:
	@echo "==> Building Docker release image..."
	docker build -f docker/Dockerfile.release -t cognitiveos:$(VERSION) .
	@echo "  done."

release: distro-tarball docker-release
	@echo "==> Release complete. Artifacts in $(OUTPUT_DIR)"
	ls -lh $(OUTPUT_DIR)/

deps:
	@echo "==> Checking dependencies..."
	@command -v docker >/dev/null 2>&1 || echo "  WARNING: docker not found"
	@command -v $(GO) >/dev/null 2>&1 || echo "  WARNING: $(GO) not found (run: scripts/build-binaries.sh)"
	@echo "  done."
