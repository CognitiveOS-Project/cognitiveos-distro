#!/bin/sh
# Orchestrate per-repo builds — clone, make build, make test, collect binaries.
# shellcheck disable=SC3040
set -eu

SRC_DIR="$(realpath "$(dirname "$0")/..")"
BUILD_DIR="${SRC_DIR}/build"
BIN_DIR="${BUILD_DIR}/bin"

# Dependency order: repos with no runtime deps first, then those that depend on them.
REPOS="cpm inference core-mcp-bridges cognitiveosd cli"

rm -rf "${BIN_DIR}"
mkdir -p "${BIN_DIR}"

for repo in ${REPOS}; do
    SRC_PATH="$(realpath "${SRC_DIR}/../${repo}")"
    if [ ! -d "${SRC_PATH}" ]; then
        echo "Cloning ${repo}..."
        gh repo clone "CognitiveOS-Project/${repo}" "${SRC_PATH}"
    fi
done


for repo in ${REPOS}; do
    SRC_PATH="$(realpath "${SRC_DIR}/../${repo}")"
    echo ""
    echo "==> ${repo}: make build"
    make -C "${SRC_PATH}" build
    echo "==> ${repo}: make test"
    make -C "${SRC_PATH}" test
    if [ -d "${SRC_PATH}/build/bin" ]; then
        cp -a "${SRC_PATH}/build/bin/"* "${BIN_DIR}/" 2>/dev/null || true
    fi
done

echo ""
echo "All binaries in ${BIN_DIR}:"
ls -la "${BIN_DIR}/"
