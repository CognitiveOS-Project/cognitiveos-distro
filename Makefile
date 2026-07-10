SHELL := /bin/sh
.SHELLFLAGS := -eu -c
.ONESHELL:
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables

OUTPUT_DIR := ./output
OVERLAY_DIR := ./overlay
BUILD_DIR := ./build
SCRIPTS_DIR := ./scripts

.PHONY: all iso rpi clean distclean docker docker.build shell checksums sign
.PHONY: install-local distro-tarball publish-cgp release deps verify-repos release-assets publish-all publish-all-safe
.PHONY: release-variant docker-release-arch docker-push-arch

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

# --- Per-architecture release targets ---

release-variant: install-local
	@VERSION=$$(git describe --tags --abbrev=0 2>/dev/null || echo "dev"); \
	echo "Building $(CLASS)-$(ARCH) release assets for v$$VERSION..."; \
	$(SHELL) $(SCRIPTS_DIR)/build-distro-tarball.sh "$$VERSION" "$(ARCH)"; \
	mkdir -p output; \
	$(SHELL) $(SCRIPTS_DIR)/build-image.sh --profile $(ARCH) --class $(CLASS)

# --- Docker per-arch targets ---

docker-release-arch:
	@VERSION=$$(cat VERSION 2>/dev/null || echo "dev"); \
	ARCH=$(ARCH); \
	CLASS=$(CLASS); \
	docker buildx build --platform linux/$(ARCH) \
		--build-arg CGO_ENABLED=1 \
		-f docker/Dockerfile.release \
		-t cognitiveos:$${VERSION}-$(CLASS)-$(ARCH) \
		-t ghcr.io/CognitiveOS-Project/cognitiveos-distro:$${VERSION}-$(CLASS)-$(ARCH) \
		--load .

docker-push-arch:
	@VERSION=$$(cat VERSION 2>/dev/null || echo "dev"); \
	ARCH=$(ARCH); \
	CLASS=$(CLASS); \
	docker push ghcr.io/CognitiveOS-Project/cognitiveos-distro:$${VERSION}-$(CLASS)-$(ARCH)

# --- Safe publish (exits 0 if REGISTRY_TOKEN missing) ---

publish-all-safe:
	@if [ -z "$${REGISTRY_TOKEN:-}" ]; then \
		echo "  WARNING: REGISTRY_TOKEN not set, skipping publish"; exit 0; \
	fi
	@for repo in cli cognitiveosd core-mcp-bridges inference cpm; do \
		echo "  Publishing $$repo..."; \
		make -C ../$$repo publish; \
	done

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

verify-repos:
	@for repo in cpm cognitiveosd cli core-mcp-bridges inference; do \
		echo "=== Verifying $$repo ==="; \
		rm -rf "/tmp/$$repo"; \
		git clone --depth=1 "https://github.com/CognitiveOS-Project/$$repo.git" "/tmp/$$repo" || true; \
		if [ "$$repo" = "inference" ]; then \
			mkdir -p "/tmp/inference/vendor"; \
			git clone --depth=1 https://github.com/ggerganov/llama.cpp.git "/tmp/inference/vendor/llama.cpp"; \
		fi; \
		CGO_ENABLED=0 make -C "/tmp/$$repo" build; \
	done

release-assets: install-local
	@VERSION=$$(git describe --tags --abbrev=0 2>/dev/null || echo "dev"); \
	echo "Building release assets for v$$VERSION..."; \
	$(SHELL) $(SCRIPTS_DIR)/build-distro-tarball.sh "$$VERSION" "x86_64"; \
	mkdir -p output; \
	$(SHELL) $(SCRIPTS_DIR)/build-image.sh --profile x86_64; \
	$(SHELL) $(SCRIPTS_DIR)/build-image.sh --profile aarch64

publish-all:
	@if [ -z "$${REGISTRY_TOKEN}" ]; then \
		echo "  ERROR: REGISTRY_TOKEN not set"; exit 1; \
	fi
	@for repo in cli cognitiveosd core-mcp-bridges inference cpm; do \
		echo "  Publishing $$repo..."; \
		make -C ../$$repo publish; \
	done

release: distro-tarball
	ls -lh $(OUTPUT_DIR)/

deps:
	@command -v docker >/dev/null 2>&1 || echo "  WARNING: docker not found"
	@command -v make >/dev/null 2>&1 || echo "  WARNING: make not found"
