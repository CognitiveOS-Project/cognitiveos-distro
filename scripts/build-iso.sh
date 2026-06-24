#!/bin/sh
set -euo pipefail

SRC_DIR="$(realpath "$(dirname "$0")/..")"
OUTPUT_DIR="${SRC_DIR}/output"
OVERLAY_DIR="${SRC_DIR}/overlay"
PROFILE="x86_64"

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

echo "Building ISO for ${PROFILE}..."

mkimage \
    --profile "${PROFILE}" \
    --outdir "${OUTPUT_DIR}" \
    --overlay "${OVERLAY_DIR}" \
    --packages "${SRC_DIR}/packages.x86_64" \
    --repository "https://dl-cdn.alpinelinux.org/alpine/edge/main" \
    --repository "https://dl-cdn.alpinelinux.org/alpine/edge/community" \
    --tag "cognitiveos-$(date +%Y%m%d)"

echo ""
echo "ISO build complete. Images in ${OUTPUT_DIR}:"
ls -lh "${OUTPUT_DIR}/"*.iso 2>/dev/null || echo "(no .iso found — check build logs)"
