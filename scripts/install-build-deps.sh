#!/bin/sh
# shellcheck disable=SC2034,SC2086
set -eu

OVERLAY_DIR="${COGNITIVEOS_OVERLAY_DIR:-/workspace/overlay}"
CPM_BIN="${CPM_BIN:-/workspace/cpm/build/bin/cpm}"

echo "  -> Checking for build-stage dependencies in $OVERLAY_DIR..."

# Ensure cpm is available
if [ ! -f "$CPM_BIN" ]; then
    echo "  -> cpm not found at $CPM_BIN, building from source..."
    BUILD_DIR="/tmp/cpm-build"
    mkdir -p "$BUILD_DIR"
    git clone --depth=1 https://github.com/CognitiveOS-Project/cpm.git "$BUILD_DIR"
    (cd "$BUILD_DIR" && make build)
    CPM_BIN="$BUILD_DIR/build/bin/cpm"
fi

# Scan for .cgp files and install build deps
found=0
for patch in $(find "$OVERLAY_DIR" -name "*.cgp"); do
    found=1
    echo "  -> Registering build dependencies for $patch..."
    "$CPM_BIN" register-dependencies "$patch"
    "$CPM_BIN" install-dependencies --stage build
done

if [ "$found" -eq 0 ]; then
    echo "  -> No .cgp patches found in overlay, skipping build dependencies."
fi
