#!/bin/sh
# shellcheck disable=SC2034,SC2153,SC3040,SC3043
set -eu

SRC_DIR="$(realpath "$(dirname "$0")/..")"
OUTPUT_DIR="${SRC_DIR}/output"
OVERLAY_DIR="${SRC_DIR}/overlay"
APORTS_DIR="/tmp/aports"
APORTS_GIT="https://gitlab.alpinelinux.org/alpine/aports.git"
MKIMAGE_DEPS="abuild apk-tools alpine-conf busybox fakeroot syslinux xorriso squashfs-tools mtools grub-efi git go"

PROFILE=""
PACKAGES_FILE=""
CLASS=""
VERSION=""

while [ $# -gt 0 ]; do
    case "$1" in
        --profile)    PROFILE="$2"; shift 2 ;;
        --class)      CLASS="$2"; shift 2 ;;
        --version)    VERSION="$2"; shift 2 ;;
        --packages)   PACKAGES_FILE="$2"; shift 2 ;;
        *) echo "Usage: $0 --profile x86_64|aarch64|armv7 [--class standard|edge|titan|gateway|micro] [--version <ver>] [--packages <file>]
"; exit 1 ;;
    esac
done

[ -n "$PROFILE" ] || { echo "ERROR: --profile is required"; exit 1; }

# Fallback to 'edge' if no class is specified
CLASS=${CLASS:-edge}

if [ -f "${SRC_DIR}/packages.${CLASS}-${PROFILE}" ]; then
    PACKAGES_FILE="${SRC_DIR}/packages.${CLASS}-${PROFILE}"
elif [ -n "$PACKAGES_FILE" ]; then
    :
else
    PACKAGES_FILE="${SRC_DIR}/packages.${PROFILE}"
fi
[ -f "$PACKAGES_FILE" ] || { echo "ERROR: packages file not found: $PACKAGES_FILE"; exit 1; }

VERSION=${VERSION:-$(git -C "${SRC_DIR}" describe --tags --abbrev=0 2>/dev/null || echo "dev")}
# Default class by profile
case "$PROFILE" in
    x86_64)  CLASS="${CLASS:-standard}" ;;
    aarch64) CLASS="${CLASS:-edge}" ;;
    armv7)   CLASS="${CLASS:-edge}" ;;
esac
TAG="${VERSION}-${CLASS}"

run_mkimage() {
    local aports_dir="$1"
    local mkimage_script="${aports_dir}/scripts/mkimage.sh"
    [ -f "$mkimage_script" ] || { echo "ERROR: mkimage.sh not found. Clone aports: git clone --depth=1 ${APORTS_GIT} ${aports_dir}"; exit 1; }

    mkdir -p "$OUTPUT_DIR"
    cp "$SRC_DIR/scripts/mkimg.cognitiveos.sh" "${aports_dir}/scripts/"
    cp "$SRC_DIR/scripts/genapkovl-cognitiveos.sh" "${aports_dir}/scripts/"

    export COGNITIVEOS_PACKAGES_FILE="$PACKAGES_FILE"
    export COGNITIVEOS_OVERLAY_DIR="$OVERLAY_DIR"

    cd "${aports_dir}/scripts"
    if [ "$(id -u)" -eq 0 ]; then
        ./mkimage.sh --profile cognitiveos --outdir "$OUTPUT_DIR" --arch "$PROFILE" \
            --repository "https://dl-cdn.alpinelinux.org/alpine/edge/main" \
            --repository "https://dl-cdn.alpinelinux.org/alpine/edge/community" \
            --tag "$TAG"
    else
        sudo -E ./mkimage.sh --profile cognitiveos --outdir "$OUTPUT_DIR" --arch "$PROFILE" \
            --repository "https://dl-cdn.alpinelinux.org/alpine/edge/main" \
            --repository "https://dl-cdn.alpinelinux.org/alpine/edge/community" \
            --tag "$TAG"
    fi

    echo ""; echo "Renaming output to spec format..."
    for f in "${OUTPUT_DIR}/cognitiveos-${TAG}"*; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        ext="${base##*.}"
        # Alpine mkimage produces: cognitiveos-{version}-{class}(-{arch}).{ext}
        # Rename to: cognitiveos-{version}-{class}-{arch}.{ext}
        if echo "$base" | grep -q "${PROFILE}\.${ext}$"; then
            # Already has arch suffix — leave it
            :
        else
            # Add arch before extension
            newname="cognitiveos-${VERSION}-${CLASS}-${PROFILE}.${ext}"
            mv "$f" "${OUTPUT_DIR}/${newname}"
            echo "  → ${newname}"
        fi
    done
	echo ""; echo "Build complete. Output in ${OUTPUT_DIR}:"
	find "$OUTPUT_DIR" -maxdepth 1 -type f ! -name "SHA256SUMS" -exec ls -lh {} +
}


if command -v apk >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
    echo "  -> Alpine + git found, building natively"
    [ "$(id -u)" -eq 0 ] && SUDO="" || SUDO="sudo"
    $SUDO apk add --no-cache $MKIMAGE_DEPS
    $SUDO "${SRC_DIR}/scripts/install-build-deps.sh"

    if [ ! -d "$APORTS_DIR" ]; then
        git clone --depth=1 "$APORTS_GIT" "$APORTS_DIR"
    else
        git -C "$APORTS_DIR" fetch --depth=1 origin
        git -C "$APORTS_DIR" reset --hard origin/master
    fi

    if [ "$(id -u)" -eq 0 ]; then
        id builder >/dev/null 2>&1 || adduser -D builder
        chown -R builder:builder "$APORTS_DIR" "$OUTPUT_DIR"
        su builder -p -c "
            export HOME=/home/builder
            export COGNITIVEOS_PACKAGES_FILE='$PACKAGES_FILE'
            export COGNITIVEOS_OVERLAY_DIR='$OVERLAY_DIR'
            abuild-keygen -a -n
            cd '$APORTS_DIR/scripts'
            ./mkimage.sh --profile cognitiveos --outdir '$OUTPUT_DIR' --arch '$PROFILE' \
                --repository 'https://dl-cdn.alpinelinux.org/alpine/edge/main' \
                --repository 'https://dl-cdn.alpinelinux.org/alpine/edge/community' \
                --tag '$TAG'
        "
    else
        abuild-keygen -a -n
        run_mkimage "$APORTS_DIR"
    fi
    exit 0
fi

if command -v docker >/dev/null 2>&1; then
    echo "  -> Building via Docker (alpine:edge)"
    mkdir -p "$OUTPUT_DIR"
    docker run --rm --privileged \
        -v "$SRC_DIR:/workspace" \
        alpine:edge sh -c "
            apk add --no-cache $MKIMAGE_DEPS
            /workspace/scripts/install-build-deps.sh
            adduser -D builder
            git clone --depth=1 ${APORTS_GIT} ${APORTS_DIR}
            cp /workspace/scripts/mkimg.cognitiveos.sh ${APORTS_DIR}/scripts/
            cp /workspace/scripts/genapkovl-cognitiveos.sh ${APORTS_DIR}/scripts/
            chown -R builder:builder ${APORTS_DIR} /workspace/output
            su builder -p -c '
                export HOME=/home/builder
                export COGNITIVEOS_PACKAGES_FILE=/workspace/packages.${CLASS}-${PROFILE}
                export COGNITIVEOS_OVERLAY_DIR=/workspace/overlay
                cd ${APORTS_DIR}/scripts
                abuild-keygen -a -n
                ./mkimage.sh --profile cognitiveos --outdir /workspace/output --arch ${PROFILE} \
                    --repository https://dl-cdn.alpinelinux.org/alpine/edge/main \
                    --repository https://dl-cdn.alpinelinux.org/alpine/edge/community \
                    --tag ${TAG}
            '
        "
    echo ""; echo "Docker build complete. Output in ${OUTPUT_DIR}:"
    ls -lh "$OUTPUT_DIR/"
    exit 0
fi

echo "ERROR: Neither apk+git nor Docker available. Run on Alpine or where Docker is installed."
exit 1
