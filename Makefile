SHELL := /bin/sh
.SHELLFLAGS := -eu -c
.ONESHELL:
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables

OUTPUT_DIR := ./output
OVERLAY_DIR := ./overlay
BUILD_DIR := ./build
SCRIPTS_DIR := ./scripts

.PHONY: all iso rpi clean distclean docker docker.build docker.release shell checksums sign
.PHONY: install-local distro-tarball publish-cgp release deps

all: iso rpi checksums sign

iso: install-local
	$(SHELL) $(SCRIPTS_DIR)/build-image.sh --profile x86_64

rpi: install-local
	$(SHELL) $(SCRIPTS_DIR)/build-image.sh --profile aarch64

clean:
	rm -rf $(BUILD_DIR) $(OUTPUT_DIR) *.iso *.img *.tar.gz

distclean: clean
	rm -rf ./cache ./work

# --- Docker build targets — Dockerfiles only call these, no repo-specific logic ---

# Build binaries + overlay (used inside Dockerfile RUN, not on host directly)
docker.build:
	$(SHELL) $(SCRIPTS_DIR)/build-binaries.sh
	$(SHELL) $(SCRIPTS_DIR)/build-overlay.sh
	mkdir -p /out 2>/dev/null && cp -a $(OVERLAY_DIR)/. /out/ 2>/dev/null; true

# Build the builder image (calls docker.build inside the container)
docker:
	docker build -f docker/Dockerfile.build -t cognitiveos-builder .

docker.release:
	docker build -f docker/Dockerfile.release \
		-t cognitiveos:$$(cat VERSION 2>/dev/null || echo "dev") \
		-t cognitiveos:latest .

# Backward compat
docker-release: docker.release

shell: docker
	docker run --rm -it \
		-v "$(CURDIR)/../cpm:/src/cpm" \
		-v "$(CURDIR)/../cognitiveosd:/src/cognitiveosd" \
		-v "$(CURDIR)/../cli:/src/cli" \
		-v "$(CURDIR)/../inference:/src/inference" \
		-v "$(CURDIR)/../core-mcp-bridges:/src/core-mcp-bridges" \
		-w /workspace \
		cognitiveos-builder /bin/sh

checksums:
	$(SHELL) $(SCRIPTS_DIR)/sign.sh

sign: checksums

install-local: deps
	@for repo in cli cognitiveosd core-mcp-bridges inference cpm; do \
		echo "  Building $$repo..."; \
		make -C ../$$repo build; \
	done
	$(SHELL) $(SCRIPTS_DIR)/build-overlay.sh

distro-tarball: install-local
	$(SHELL) $(SCRIPTS_DIR)/build-distro-tarball.sh

publish-cgp:
	@if [ -z "$${REGISTRY_TOKEN}" ]; then \
		echo "  ERROR: REGISTRY_TOKEN not set"; exit 1; \
	fi
	@VERSION=$$(git describe --tags --abbrev=0 2>/dev/null || echo "dev")
	@for repo in cli cognitiveosd core-mcp-bridges inference cpm; do \
		echo "  Packaging and publishing $$repo..."; \
		make -C ../$$repo pack; \
		for cgp in ../$$repo/*.cgp; do \
			[ -f "$$cgp" ] || continue; \
			URL="https://github.com/CognitiveOS-Project/$$repo/releases/download/$$VERSION/$$(basename $$cgp)"; \
			/workspace/cpm/build/bin/cpm publish "$$cgp" --download-url "$$URL"; \
			rm "$$cgp"; \
		done; \
	done

release: distro-tarball docker.release
	ls -lh $(OUTPUT_DIR)/

deps:
	@command -v docker >/dev/null 2>&1 || echo "  WARNING: docker not found"
	@command -v make >/dev/null 2>&1 || echo "  WARNING: make not found"
