#!/bin/sh
# shellcheck disable=SC3040
set -eu

OUTPUT_DIR="$(realpath "$(dirname "$0")/..")/output"

[ -d "${OUTPUT_DIR}" ] || { echo "ERROR: output directory ${OUTPUT_DIR} does not exist"; exit 1; }

cd "${OUTPUT_DIR}"
sha256sum -- * > SHA256SUMS 2>/dev/null || { echo "No files to checksum"; exit 0; }

echo "Checksums: ${OUTPUT_DIR}/SHA256SUMS"

if [ -n "${SIGNING_KEY:-}" ]; then
    gpg --detach-sign --armor --default-key "${SIGNING_KEY}" \
        --output SHA256SUMS.asc SHA256SUMS
elif command -v gpg >/dev/null 2>&1 && gpg --list-keys >/dev/null 2>&1; then
    gpg --detach-sign --armor --output SHA256SUMS.asc SHA256SUMS 2>/dev/null && \
        echo "Signed: ${OUTPUT_DIR}/SHA256SUMS.asc" || true
fi
