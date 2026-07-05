#!/bin/sh
set -euo pipefail

SRC_DIR="$(realpath "$(dirname "$0")/..")"
OUTPUT_DIR="${SRC_DIR}/output"
OVERLAY_DIR="${SRC_DIR}/overlay"
PROFILE="aarch64"

echo "Checking prerequisites..."

if ! command -v mkimage >/dev/null 2>&1; then
    echo "ERROR: mkimage not found. Install alpine-conf (apk add alpine-conf)."
    exit 1
fi

if ! command -v apk >/dev/null 2>&1; then
    echo "ERROR: apk-tools-static not found."
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"

echo "Building Raspberry Pi image for ${PROFILE}..."

mkimage \
    --profile "${PROFILE}" \
    --outdir "${OUTPUT_DIR}" \
    --overlay "${OVERLAY_DIR}" \
    --packages "${SRC_DIR}/packages.aarch64" \
    --repository "https://dl-cdn.alpinelinux.org/alpine/edge/main" \
    --repository "https://dl-cdn.alpinelinux.org/alpine/edge/community" \
    --tag "cognitiveos-rpi-$(date +%Y%m%d)"

echo ""
echo "RPi build complete. Images in ${OUTPUT_DIR}:"
ls -lh "${OUTPUT_DIR}/"*.img 2>/dev/null || echo "(no .img found — check build logs)"
