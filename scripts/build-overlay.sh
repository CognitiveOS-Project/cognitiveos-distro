#!/bin/sh
set -euo pipefail

SRC_DIR="$(realpath "$(dirname "$0")/..")"
OVERLAY_DIR="${SRC_DIR}/overlay"
BIN_DIR="${SRC_DIR}/build/bin"

echo "Creating overlay directory structure..."

mkdir -p "${OVERLAY_DIR}/usr/local/bin"
mkdir -p "${OVERLAY_DIR}/usr/local/lib/cognitiveos/bridges"
mkdir -p "${OVERLAY_DIR}/etc/cognitiveos"
mkdir -p "${OVERLAY_DIR}/etc/wpa_supplicant"
mkdir -p "${OVERLAY_DIR}/cognitiveos/run"
mkdir -p "${OVERLAY_DIR}/cognitiveos/patches"
mkdir -p "${OVERLAY_DIR}/cognitiveos/data"
mkdir -p "${OVERLAY_DIR}/cognitiveos/packages"

echo "Copying binaries..."

if [ -f "${BIN_DIR}/cognitiveos-cli" ]; then
    cp "${BIN_DIR}/cognitiveos-cli" "${OVERLAY_DIR}/usr/local/bin/cognitiveos-cli"
    chmod 755 "${OVERLAY_DIR}/usr/local/bin/cognitiveos-cli"
    echo "  -> cognitiveos-cli"
fi

if [ -f "${BIN_DIR}/cognitiveosd" ]; then
    cp "${BIN_DIR}/cognitiveosd" "${OVERLAY_DIR}/usr/local/bin/cognitiveosd"
    chmod 755 "${OVERLAY_DIR}/usr/local/bin/cognitiveosd"
    echo "  -> cognitiveosd"
fi

if [ -f "${BIN_DIR}/cognitiveos-inference" ]; then
    cp "${BIN_DIR}/cognitiveos-inference" "${OVERLAY_DIR}/usr/local/bin/cognitiveos-inference"
    chmod 755 "${OVERLAY_DIR}/usr/local/bin/cognitiveos-inference"
    echo "  -> cognitiveos-inference"
fi

if [ -f "${BIN_DIR}/cpm" ]; then
    cp "${BIN_DIR}/cpm" "${OVERLAY_DIR}/usr/local/bin/cpm"
    chmod 755 "${OVERLAY_DIR}/usr/local/bin/cpm"
    echo "  -> cpm"
fi

if [ -d "${BIN_DIR}/bridges" ]; then
    for bridge_bin in "${BIN_DIR}/bridges/"*; do
        if [ -f "${bridge_bin}" ]; then
            cp "${bridge_bin}" "${OVERLAY_DIR}/usr/local/lib/cognitiveos/bridges/"
            chmod 755 "${OVERLAY_DIR}/usr/local/lib/cognitiveos/bridges/$(basename "${bridge_bin}")"
            echo "  -> bridge: $(basename "${bridge_bin}")"
        fi
    done
fi

echo "Setting root ownership..."
chown -R 0:0 "${OVERLAY_DIR}" 2>/dev/null || echo "  (not running as root, ownership unchanged)"

echo ""
echo "Overlay prepared at ${OVERLAY_DIR}"
