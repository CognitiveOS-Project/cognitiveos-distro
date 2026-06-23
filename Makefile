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

.PHONY: all iso rpi clean distclean docker shell checksums sign install-local deps

all: iso rpi checksums sign

iso: deps
	@echo "==> Building x86_64 ISO..."
	@bash $(SCRIPTS_DIR)/build-iso.sh

rpi: deps
	@echo "==> Building aarch64 RPi image..."
	@bash $(SCRIPTS_DIR)/build-rpi.sh

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
		-v "$(CURDIR):/workspace" \
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

deps:
	@echo "==> Checking dependencies..."
	@command -v mkimage >/dev/null 2>&1 || echo "  WARNING: mkimage not found (install alpine-conf)"
	@command -v docker >/dev/null 2>&1 || echo "  WARNING: docker not found"
	@command -v $(GO) >/dev/null 2>&1 || echo "  WARNING: $(GO) not found"
	@echo "  done."
