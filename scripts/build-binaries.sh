#!/bin/sh
set -euo pipefail

BUILD_DIR="$(realpath "$(dirname "$0")/..")/build"
BIN_DIR="${BUILD_DIR}/bin"
SRC_DIR="$(realpath "$(dirname "$0")/..")"

GO="/tmp/go/bin/go"

REPOS="cpm cognitiveosd cli inference core-mcp-bridges"

mkdir -p "${BIN_DIR}"

for repo in ${REPOS}; do
    SRC_PATH="${SRC_DIR}/../${repo}"
    if [ ! -d "${SRC_PATH}" ]; then
        echo "Cloning ${repo} from GitHub..."
        git clone --depth=1 "git@github.com:CognitiveOS-Project/${repo}.git" "${SRC_PATH}"
    fi
done

echo "Building cpm..."
cd "${SRC_DIR}/../cpm"
CGO_ENABLED=0 GOOS=linux ${GO} build -ldflags="-s -w" -o "${BIN_DIR}/cpm" .
echo "  -> cpm built"

echo "Building cognitiveosd..."
cd "${SRC_DIR}/../cognitiveosd"
CGO_ENABLED=0 GOOS=linux ${GO} build -ldflags="-s -w" -o "${BIN_DIR}/cognitiveosd" .
echo "  -> cognitiveosd built"

echo "Building cli..."
cd "${SRC_DIR}/../cli"
CGO_ENABLED=0 GOOS=linux ${GO} build -ldflags="-s -w" -o "${BIN_DIR}/cognitiveos-cli" .
echo "  -> cognitiveos-cli built"

echo "Building inference..."
cd "${SRC_DIR}/../inference"
CGO_ENABLED=0 GOOS=linux ${GO} build -ldflags="-s -w" -o "${BIN_DIR}/cognitiveos-inference" .
echo "  -> cognitiveos-inference built"

echo "Building core-mcp-bridges..."
cd "${SRC_DIR}/../core-mcp-bridges"
BRIDGE_BIN_DIR="${BIN_DIR}/bridges"
mkdir -p "${BRIDGE_BIN_DIR}"
for dir in */; do
    bridge=$(basename "${dir}")
    if [ -f "${dir}main.go" ] || [ -f "${dir}go.mod" ] || [ -f "${dir}Makefile" ]; then
        echo "  Building bridge: ${bridge}..."
        CGO_ENABLED=0 GOOS=linux ${GO} build -ldflags="-s -w" -o "${BRIDGE_BIN_DIR}/${bridge}" "./${dir}" || echo "  WARNING: bridge ${bridge} build failed, skipping"
    fi
done
echo "  -> core-mcp-bridges built"

echo ""
echo "All binaries built successfully in ${BIN_DIR}"
