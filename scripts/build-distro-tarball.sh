#!/bin/sh
set -euo pipefail

SRC_DIR="$(realpath "$(dirname "$0")/..")"
OUTPUT_DIR="${SRC_DIR}/output"
OVERLAY_DIR="${SRC_DIR}/overlay"
BUILD_DIR="${SRC_DIR}/build"

VERSION="${1:-$(date +%Y%m%d)}"
ARCH="${2:-x86_64}"
TARBALL="${OUTPUT_DIR}/cognitiveos-distro-${VERSION}-${ARCH}.tar.gz"

echo "==> Building distro tarball v${VERSION} (${ARCH})..."
echo ""

# Build binaries first
if [ ! -f "${BUILD_DIR}/bin/cpm" ]; then
    echo "==> Building binaries..."
    "${SRC_DIR}/scripts/build-binaries.sh"
fi

# Assemble overlay
echo "==> Assembling overlay..."
"${SRC_DIR}/scripts/build-overlay.sh"

# Create output dir
mkdir -p "${OUTPUT_DIR}"

# Package overlay + package lists + metadata
echo "==> Creating tarball..."
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "${WORKDIR}/cognitiveos-distro-${VERSION}"

cp -r "${OVERLAY_DIR}/." "${WORKDIR}/cognitiveos-distro-${VERSION}/rootfs/"
cp "${SRC_DIR}/packages.${ARCH}" "${WORKDIR}/cognitiveos-distro-${VERSION}/packages.txt" 2>/dev/null || true

# Version metadata
cat > "${WORKDIR}/cognitiveos-distro-${VERSION}/VERSION" <<EOF
COGNITIVEOS_DISTRO_VERSION=${VERSION}
COGNITIVEOS_DISTRO_ARCH=${ARCH}
COGNITIVEOS_DISTRO_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

# Copy build scripts reference
mkdir -p "${WORKDIR}/cognitiveos-distro-${VERSION}/scripts"
cp "${SRC_DIR}/scripts/build-iso.sh" "${WORKDIR}/cognitiveos-distro-${VERSION}/scripts/"
cp "${SRC_DIR}/scripts/build-rpi.sh" "${WORKDIR}/cognitiveos-distro-${VERSION}/scripts/"
cp "${SRC_DIR}/scripts/sign.sh" "${WORKDIR}/cognitiveos-distro-${VERSION}/scripts/"

cd "${WORKDIR}"
tar czf "${TARBALL}" "cognitiveos-distro-${VERSION}/"

echo ""
echo "  ✓ Distro tarball: ${TARBALL}"
echo "    Size: $(du -h "${TARBALL}" | cut -f1)"

cd "${OUTPUT_DIR}"
sha256sum "$(basename "${TARBALL}")" >> "${OUTPUT_DIR}/SHA256SUMS" 2>/dev/null || true
