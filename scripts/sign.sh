#!/bin/bash
set -euo pipefail

SRC_DIR="$(realpath "$(dirname "$0")/..")"
OUTPUT_DIR="${SRC_DIR}/output"

if [ ! -d "${OUTPUT_DIR}" ]; then
    echo "ERROR: output directory ${OUTPUT_DIR} does not exist. Run build first."
    exit 1
fi

echo "Generating SHA-256 checksums..."

cd "${OUTPUT_DIR}"
sha256sum -- * > "${OUTPUT_DIR}/SHA256SUMS" 2>/dev/null || {
    echo "No files to checksum in ${OUTPUT_DIR}"
    exit 0
}

echo "  -> ${OUTPUT_DIR}/SHA256SUMS"

if [ -n "${SIGNING_KEY:-}" ]; then
    echo "Signing checksums with GPG key ${SIGNING_KEY}..."
    gpg --detach-sign --armor \
        --default-key "${SIGNING_KEY}" \
        --output "${OUTPUT_DIR}/SHA256SUMS.asc" \
        "${OUTPUT_DIR}/SHA256SUMS"
    echo "  -> ${OUTPUT_DIR}/SHA256SUMS.asc"
elif command -v gpg >/dev/null 2>&1 && gpg --list-keys >/dev/null 2>&1; then
    echo "Signing checksums with default GPG key..."
    gpg --detach-sign --armor \
        --output "${OUTPUT_DIR}/SHA256SUMS.asc" \
        "${OUTPUT_DIR}/SHA256SUMS" 2>/dev/null && \
    echo "  -> ${OUTPUT_DIR}/SHA256SUMS.asc" || \
    echo "  (no default GPG key available, skipping sign)"
else
    echo "  (no GPG key available, skipping sign)"
fi

echo ""
echo "Signing complete."
