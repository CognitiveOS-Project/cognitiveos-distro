#!/bin/sh
# shellcheck disable=SC3040
set -eu

SRC_DIR="$(realpath "$(dirname "$0")/..")"
OVERLAY_DIR="${SRC_DIR}/overlay"
BIN_DIR="${SRC_DIR}/build/bin"

BINARIES="cognitiveos-cli cognitiveosd cognitiveos-inference cpm"

mkdir -p "${OVERLAY_DIR}/usr/local/bin"
mkdir -p "${OVERLAY_DIR}/usr/local/lib/cognitiveos/bridges"
mkdir -p "${OVERLAY_DIR}/etc/cognitiveos"
mkdir -p "${OVERLAY_DIR}/etc/wpa_supplicant"
mkdir -p "${OVERLAY_DIR}/cognitiveos/run"
mkdir -p "${OVERLAY_DIR}/cognitiveos/patches"
mkdir -p "${OVERLAY_DIR}/cognitiveos/data"
mkdir -p "${OVERLAY_DIR}/cognitiveos/packages"

for bin in ${BINARIES}; do
    src="${BIN_DIR}/${bin}"
    if [ -f "${src}" ]; then
        cp "${src}" "${OVERLAY_DIR}/usr/local/bin/${bin}"
        chmod 755 "${OVERLAY_DIR}/usr/local/bin/${bin}"
    fi
done

if [ -d "${BIN_DIR}/bridges" ]; then
    for bridge_bin in "${BIN_DIR}/bridges/"*; do
        if [ -f "${bridge_bin}" ]; then
            cp "${bridge_bin}" "${OVERLAY_DIR}/usr/local/lib/cognitiveos/bridges/"
            chmod 755 "${OVERLAY_DIR}/usr/local/lib/cognitiveos/bridges/$(basename "${bridge_bin}")"
        fi
    done
fi

chown -R 0:0 "${OVERLAY_DIR}" 2>/dev/null || true

echo "Overlay prepared at ${OVERLAY_DIR}"
