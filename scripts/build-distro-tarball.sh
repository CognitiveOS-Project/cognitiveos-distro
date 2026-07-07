#!/bin/bash
set -euo pipefail

SRC_DIR="$(realpath "$(dirname "$0")/..")"
OUTPUT_DIR="${SRC_DIR}/output"
OVERLAY_DIR="${SRC_DIR}/overlay"
BUILD_DIR="${SRC_DIR}/build"
VERSION="${1:-$(date +%Y%m%d)}"
ARCH="${2:-x86_64}"
TARBALL="${OUTPUT_DIR}/cognitiveos-distro-${VERSION}-${ARCH}.tar.gz"

if [ ! -f "${BUILD_DIR}/bin/cpm" ]; then
    "${SRC_DIR}/scripts/build-binaries.sh"
fi
"${SRC_DIR}/scripts/build-overlay.sh"

mkdir -p "${OUTPUT_DIR}"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

DISTDIR="${WORKDIR}/cognitiveos-distro-${VERSION}"
mkdir -p "${DISTDIR}/rootfs" "${DISTDIR}/scripts"
cp -r "${OVERLAY_DIR}/." "${DISTDIR}/rootfs/"
cp "${SRC_DIR}/packages.${ARCH}" "${DISTDIR}/packages.txt" 2>/dev/null || true

cat > "${DISTDIR}/VERSION" <<EOF
COGNITIVEOS_DISTRO_VERSION=${VERSION}
COGNITIVEOS_DISTRO_ARCH=${ARCH}
COGNITIVEOS_DISTRO_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

cp "${SRC_DIR}/scripts/build-image.sh" "${DISTDIR}/scripts/"
cp "${SRC_DIR}/scripts/sign.sh" "${DISTDIR}/scripts/"

cd "${WORKDIR}"
tar czf "${TARBALL}" "cognitiveos-distro-${VERSION}/"

sha256sum "$(basename "${TARBALL}")" >> "${OUTPUT_DIR}/SHA256SUMS" 2>/dev/null || true

echo "  Distro tarball: ${TARBALL} ($(du -h "${TARBALL}" | cut -f1))"
