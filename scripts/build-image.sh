#!/bin/sh
# build-image.sh — Build bootable CognitiveOS image (ISO or RPi) via mkimage
#
# Usage:
#   scripts/build-image.sh --profile x86_64
#   scripts/build-image.sh --profile aarch64
#   scripts/build-image.sh --profile x86_64 --packages packages.x86_64
#
# Auto-detects environment:
#   - Alpine host with mkimage  → builds directly
#   - Docker available          → re-executes inside alpine:edge container
#   - Neither                  → prints clear error

set -euo pipefail

SRC_DIR="$(realpath "$(dirname "$0")/..")"
OUTPUT_DIR="${SRC_DIR}/output"
OVERLAY_DIR="${SRC_DIR}/overlay"

# --- arg parse ---
PROFILE=""
PACKAGES_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --profile)
            PROFILE="$2"; shift 2 ;;
        --packages)
            PACKAGES_FILE="$2"; shift 2 ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 --profile x86_64|aarch64 [--packages <file>]"
            exit 1
            ;;
    esac
done

if [ -z "$PROFILE" ]; then
    echo "ERROR: --profile is required (x86_64 or aarch64)"
    exit 1
fi

if [ -z "$PACKAGES_FILE" ]; then
    PACKAGES_FILE="${SRC_DIR}/packages.${PROFILE}"
fi

if [ ! -f "$PACKAGES_FILE" ]; then
    echo "ERROR: packages file not found: $PACKAGES_FILE"
    exit 1
fi

# --- detect mkimage ---
if command -v mkimage >/dev/null 2>&1; then
    # Native Alpine build
    echo "==> mkimage available, building natively"

    if ! command -v apk >/dev/null 2>&1; then
        echo "ERROR: apk not found (required for mkimage on Alpine)"
        exit 1
    fi

    mkdir -p "${OUTPUT_DIR}"

    TAG="cognitiveos-${PROFILE}-$(date +%Y%m%d)"
    if [ "${PROFILE}" = "aarch64" ]; then
        TAG="cognitiveos-rpi-$(date +%Y%m%d)"
    fi

    mkimage \
        --profile "${PROFILE}" \
        --outdir "${OUTPUT_DIR}" \
        --overlay "${OVERLAY_DIR}" \
        --packages "${PACKAGES_FILE}" \
        --repository "https://dl-cdn.alpinelinux.org/alpine/edge/main" \
        --repository "https://dl-cdn.alpinelinux.org/alpine/edge/community" \
        --tag "${TAG}"

    echo ""
    echo "Build complete. Output in ${OUTPUT_DIR}:"
    ls -lh "${OUTPUT_DIR}/"
    exit 0
fi

# --- fallback: Docker ---
if command -v docker >/dev/null 2>&1; then
    echo "==> mkimage not found, building via Docker"

    MKDeps="alpine-conf alpine-base e2fsprogs squashfs-tools dosfstools mtools"
    docker run --rm --privileged \
        -v "${SRC_DIR}:/workspace" \
        alpine:edge sh -c "
            apk add --no-cache ${MKDeps}
            cd /workspace
            bash scripts/build-image.sh --profile '${PROFILE}' --packages '${PACKAGES_FILE}'
        "

    echo ""
    echo "Docker build complete. Output in ${OUTPUT_DIR}:"
    ls -lh "${OUTPUT_DIR}/"
    exit 0
fi

# --- neither ---
echo "ERROR: mkimage (alpine-conf) not found and Docker is not available."
echo ""
echo "To build images you need one of:"
echo "  - Alpine Linux with: apk add alpine-conf"
echo "  - Docker (any platform)"
exit 1
