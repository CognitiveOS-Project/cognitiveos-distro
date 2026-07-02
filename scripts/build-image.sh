#!/bin/bash
# build-image.sh — Build bootable CognitiveOS image via Alpine mkimage.sh
#
# Usage:
#   scripts/build-image.sh --profile x86_64
#   scripts/build-image.sh --profile aarch64
#   scripts/build-image.sh --profile x86_64 --packages packages.x86_64
#
# Auto-detects environment:
#   - Alpine host with apk + git → clones aports, builds natively
#   - Docker available           → runs inside alpine:edge container
#   - Neither                   → prints clear error

set -euo pipefail

SRC_DIR="$(realpath "$(dirname "$0")/..")"
OUTPUT_DIR="${SRC_DIR}/output"
OVERLAY_DIR="${SRC_DIR}/overlay"
APORTS_DIR="/tmp/aports"
APORTS_GIT="https://gitlab.alpinelinux.org/alpine/aports.git"

MKIMAGE_DEPS="abuild apk-tools alpine-conf busybox fakeroot syslinux xorriso squashfs-tools mtools grub-efi git"

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

TAG="cognitiveos-${PROFILE}-$(date +%Y%m%d)"

# ---------- helper: run mkimage ----------
run_mkimage() {
    local aports_dir="$1"
    local mkimage_script="${aports_dir}/scripts/mkimage.sh"

    if [ ! -f "$mkimage_script" ]; then
        echo "ERROR: mkimage.sh not found at ${mkimage_script}"
        echo "  Clone the Alpine aports repo first:"
        echo "    git clone --depth=1 ${APORTS_GIT} ${aports_dir}"
        exit 1
    fi

    mkdir -p "$OUTPUT_DIR"

    cp "$SRC_DIR/scripts/mkimg.cognitiveos.sh" "${aports_dir}/scripts/"
    cp "$SRC_DIR/scripts/genapkovl-cognitiveos.sh" "${aports_dir}/scripts/"

    export COGNITIVEOS_PACKAGES_FILE="$PACKAGES_FILE"
    export COGNITIVEOS_OVERLAY_DIR="$OVERLAY_DIR"

    cd "${aports_dir}/scripts"

    echo "==> Running mkimage.sh --profile cognitiveos --arch ${PROFILE} ..."

    if [ "$(id -u)" -eq 0 ]; then
        ./mkimage.sh \
            --profile cognitiveos \
            --outdir "$OUTPUT_DIR" \
            --arch "$PROFILE" \
            --repository "https://dl-cdn.alpinelinux.org/alpine/edge/main" \
            --repository "https://dl-cdn.alpinelinux.org/alpine/edge/community" \
            --tag "$TAG"
    else
        sudo -E ./mkimage.sh \
            --profile cognitiveos \
            --outdir "$OUTPUT_DIR" \
            --arch "$PROFILE" \
            --repository "https://dl-cdn.alpinelinux.org/alpine/edge/main" \
            --repository "https://dl-cdn.alpinelinux.org/alpine/edge/community" \
            --tag "$TAG"
    fi

    echo ""
    echo "Build complete. Output in ${OUTPUT_DIR}:"
    ls -lh "$OUTPUT_DIR/"
}

# ---------- native build (Alpine host) ----------
if command -v apk >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
    echo "==> Alpine + git found, building natively"

    echo "  -> Installing mkimage dependencies..."
    if [ "$(id -u)" -eq 0 ]; then
        apk add --no-cache $MKIMAGE_DEPS
    else
        sudo apk add --no-cache $MKIMAGE_DEPS
    fi

    echo "  -> Generating abuild signing key..."
    if [ "$(id -u)" -eq 0 ]; then
        abuild-keygen -a -n
    else
        sudo abuild-keygen -a -n
    fi

    if [ ! -d "$APORTS_DIR" ]; then
        echo "  -> Cloning Alpine aports repo (shallow)..."
        git clone --depth=1 "$APORTS_GIT" "$APORTS_DIR"
    else
        echo "  -> Updating existing aports clone..."
        git -C "$APORTS_DIR" fetch --depth=1 origin
        git -C "$APORTS_DIR" reset --hard origin/master
    fi

    run_mkimage "$APORTS_DIR"
    exit 0
fi

# ---------- Docker fallback ----------
if command -v docker >/dev/null 2>&1; then
    echo "==> Building via Docker (alpine:edge)"

    mkdir -p "$OUTPUT_DIR"

    # Write helper script to avoid complex quoting for Docker + su
    cat > /tmp/build-cognitiveos-docker.sh << ENDSCRIPT
set -eux
apk add --no-cache ${MKIMAGE_DEPS}
adduser -D builder
git clone --depth=1 ${APORTS_GIT} ${APORTS_DIR}
cp /workspace/scripts/mkimg.cognitiveos.sh ${APORTS_DIR}/scripts/
cp /workspace/scripts/genapkovl-cognitiveos.sh ${APORTS_DIR}/scripts/
chown -R builder:builder ${APORTS_DIR} /workspace/output
su builder -p -c "
export HOME=/home/builder
export COGNITIVEOS_PACKAGES_FILE=/workspace/packages.${PROFILE}
export COGNITIVEOS_OVERLAY_DIR=/workspace/overlay
cd ${APORTS_DIR}/scripts
abuild-keygen -a -n
./mkimage.sh \
    --profile cognitiveos \
    --outdir /workspace/output \
    --arch ${PROFILE} \
    --repository https://dl-cdn.alpinelinux.org/alpine/edge/main \
    --repository https://dl-cdn.alpinelinux.org/alpine/edge/community \
    --tag ${TAG}
"
ENDSCRIPT

    docker run --rm --privileged \
        -v "$SRC_DIR:/workspace" \
        -v /tmp/build-cognitiveos-docker.sh:/build.sh:ro \
        alpine:edge sh /build.sh

    echo ""
    echo "Docker build complete. Output in ${OUTPUT_DIR}:"
    ls -lh "$OUTPUT_DIR/"
    exit 0
fi

# --- neither ---
echo "ERROR: Neither apk+git nor Docker is available."
echo "  Run this script on an Alpine Linux host or where Docker is available."
exit 1
