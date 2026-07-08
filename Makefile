SHELL := /bin/sh
.SHELLFLAGS := -eu -c
.ONESHELL:
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables

OUTPUT_DIR := ./output
OVERLAY_DIR := ./overlay
BUILD_DIR := ./build
SCRIPTS_DIR := ./scripts

.PHONY: all iso rpi clean distclean docker shell checksums sign
.PHONY: install-local distro-tarball publish-cgp docker-release release deps

all: iso rpi checksums sign

iso: install-local
	$(SHELL) $(SCRIPTS_DIR)/build-image.sh --profile x86_64

rpi: install-local
	$(SHELL) $(SCRIPTS_DIR)/build-image.sh --profile aarch64

clean:
	rm -rf $(BUILD_DIR) $(OUTPUT_DIR) *.iso *.img *.tar.gz

distclean: clean
	rm -rf ./cache ./work

docker:
	docker build -f docker/Dockerfile.build -t cognitiveos-builder .

shell:
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
	$(SHELL) $(SCRIPTS_DIR)/build-binaries.sh
	$(SHELL) $(SCRIPTS_DIR)/build-overlay.sh

distro-tarball: install-local
	$(SHELL) $(SCRIPTS_DIR)/build-distro-tarball.sh

publish-cgp:
	@if [ -z "$${REGISTRY_TOKEN}" ]; then \
		echo "  ERROR: REGISTRY_TOKEN not set"; exit 1; \
	fi
	@VERSION=$$(git describe --tags --abbrev=0 2>/dev/null || echo "dev")
	@for bin in $(BUILD_DIR)/bin/*; do \
		name=$$(basename "$$bin"); \
		[ "$$name" = "bridges" ] && continue; \
		$(SHELL) $(SCRIPTS_DIR)/publish-cgp.sh --name "$$name" --version "$$VERSION" --binary "$$bin"; \
	done

docker-release:
	docker build -f docker/Dockerfile.release \
		-t cognitiveos:$$(git describe --tags --abbrev=0 2>/dev/null || echo "dev") \
		-t cognitiveos:latest .

release: distro-tarball docker-release
	ls -lh $(OUTPUT_DIR)/

deps:
	@command -v docker >/dev/null 2>&1 || echo "  WARNING: docker not found"
	@command -v make >/dev/null 2>&1 || echo "  WARNING: make not found"
