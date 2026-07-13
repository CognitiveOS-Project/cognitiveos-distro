#!/bin/sh
# shellcheck disable=SC3040
set -eu

SRC_DIR="$(realpath "$(dirname "$0")/..")"
OVERLAY_DIR="${SRC_DIR}/overlay"
BIN_DIR="${SRC_DIR}/build/bin"

VERSION=""
while [ $# -gt 0 ]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        *) echo "Usage: $0 [--version <ver>]"; exit 1 ;;
    esac
done
VERSION=${VERSION:-$(git -C "${SRC_DIR}" describe --tags --abbrev=0 2>/dev/null || echo "dev")}

rm -rf "${OVERLAY_DIR}/usr/local/bin"
rm -rf "${OVERLAY_DIR}/usr/local/lib/cognitiveos/bridges"
rm -rf "${OVERLAY_DIR}/cognitiveos/models/raw"
rm -rf "${OVERLAY_DIR}/cognitiveos/models/wide/active"
mkdir -p "${OVERLAY_DIR}/usr/local/bin"
mkdir -p "${OVERLAY_DIR}/usr/local/lib/cognitiveos/bridges"
mkdir -p "${OVERLAY_DIR}/etc/cognitiveos"
mkdir -p "${OVERLAY_DIR}/etc/wpa_supplicant"
mkdir -p "${OVERLAY_DIR}/cognitiveos/run"
mkdir -p "${OVERLAY_DIR}/cognitiveos/patches"
mkdir -p "${OVERLAY_DIR}/cognitiveos/data"
mkdir -p "${OVERLAY_DIR}/cognitiveos/packages"
mkdir -p "${OVERLAY_DIR}/cognitiveos/models/raw"
mkdir -p "${OVERLAY_DIR}/cognitiveos/models/wide/active"

# Copy all binaries — no hardcoded names, each repo owns its output
for f in "${BIN_DIR}"/*; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    [ "$name" = "bridges" ] && continue
    cp "$f" "${OVERLAY_DIR}/usr/local/bin/$name"
    chmod 755 "${OVERLAY_DIR}/usr/local/bin/$name"
done

if [ -d "${BIN_DIR}/bridges" ]; then
    for f in "${BIN_DIR}/bridges/"*; do
        [ -f "$f" ] || continue
        cp "$f" "${OVERLAY_DIR}/usr/local/lib/cognitiveos/bridges/"
        chmod 755 "${OVERLAY_DIR}/usr/local/lib/cognitiveos/bridges/$(basename "$f")"
    done
fi

# Download models (skip if no cpm binary or network unavailable)
CLASS="${CLASS:-standard}"
case "$CLASS" in
    titan)
        RAW_MODEL_QUERY="qwen2.5-235b-instruct-gguf"
        WIDE_MODEL_QUERY=""
        ;;
    standard)
        RAW_MODEL_QUERY="qwen2.5-1.5b-instruct-gguf"
        WIDE_MODEL_QUERY="gemma-4-8b-instruct-gguf"
        ;;
    gateway)
        RAW_MODEL_QUERY=""
        WIDE_MODEL_QUERY=""
        ;;
    edge)
        RAW_MODEL_QUERY="qwen2.5-0.5b-instruct-gguf"
        WIDE_MODEL_QUERY="tiny-llm-gguf"
        ;;
    micro)
        RAW_MODEL_QUERY=""
        WIDE_MODEL_QUERY=""
        ;;
    *)
        RAW_MODEL_QUERY="qwen2.5-1.5b-instruct-gguf"
        WIDE_MODEL_QUERY="qwen2.5-3b-instruct-gguf"
        ;;
esac

CPM="${BIN_DIR}/cpm"
if [ -x "$CPM" ]; then
    if [ -n "${DOWNLOAD_MODELS:-}" ]; then
        if [ -n "$RAW_MODEL_QUERY" ]; then
            echo "  Downloading Raw Model (smallest GGUF for \"${RAW_MODEL_QUERY}\")..."
            "$CPM" download-weights --kind raw --type gguf \
                --output "${OVERLAY_DIR}/cognitiveos/models/raw/raw-model.gguf" \
                "${RAW_MODEL_QUERY}" 2>/dev/null || echo "  WARNING: Raw Model download failed — skipping"
            chmod 0400 "${OVERLAY_DIR}/cognitiveos/models/raw/raw-model.gguf" 2>/dev/null || true
        else
            echo "  SKIP: Raw Model is compiled-in for class \"${CLASS}\""
        fi

        if [ -n "$WIDE_MODEL_QUERY" ]; then
            echo "  Downloading Wide Model (smallest GGUF for \"${WIDE_MODEL_QUERY}\")..."
            "$CPM" download-weights --kind wide --type gguf \
                --output "${OVERLAY_DIR}/cognitiveos/models/wide/active/model.gguf" \
                "${WIDE_MODEL_QUERY}" 2>/dev/null || echo "  WARNING: Wide Model download failed — skipping"
        else
            echo "  SKIP: Wide Model is remote-only for class \"${CLASS}\""
        fi
    else
        echo "  SKIP: model download disabled (set DOWNLOAD_MODELS=1 to enable)"
    fi
fi

# Generate image manifest
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "${OVERLAY_DIR}/etc/cognitiveos/image-manifest.json" <<EOF
{
  "image_version": "${VERSION}",
  "build_date": "${BUILD_DATE}",
  "alpine_version": "edge",
  "cognitiveos_components": {}
}
EOF

chown -R 0:0 "${OVERLAY_DIR}" 2>/dev/null || true

echo "Overlay prepared at ${OVERLAY_DIR}"
