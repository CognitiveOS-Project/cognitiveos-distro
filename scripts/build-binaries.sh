#!/bin/bash
set -euo pipefail

BUILD_DIR="$(realpath "$(dirname "$0")/..")/build"
BIN_DIR="${BUILD_DIR}/bin"
SRC_DIR="$(realpath "$(dirname "$0")/..")"

GO="$(command -v go 2>/dev/null || echo "/tmp/go/bin/go")"

REPOS="cpm cognitiveosd cli inference core-mcp-bridges"

mkdir -p "${BIN_DIR}"

for repo in ${REPOS}; do
    SRC_PATH="${SRC_DIR}/../${repo}"
    if [ ! -d "${SRC_PATH}" ]; then
        echo "Cloning ${repo} from GitHub..."
        git clone --depth=1 "https://github.com/CognitiveOS-Project/${repo}.git" "${SRC_PATH}"
    fi
done

echo "Building cpm..."
cd "${SRC_DIR}/../cpm"
CGO_ENABLED=0 GOOS=linux ${GO} build -ldflags="-s -w" -o "${BIN_DIR}/cpm" ./cmd/cpm
echo "  -> cpm built"

echo "Building cognitiveosd..."
cd "${SRC_DIR}/../cognitiveosd"
CGO_ENABLED=0 GOOS=linux ${GO} build -ldflags="-s -w" -o "${BIN_DIR}/cognitiveosd" ./cmd/cognitiveosd
echo "  -> cognitiveosd built"

echo "Building cli..."
cd "${SRC_DIR}/../cli"
CGO_ENABLED=0 GOOS=linux ${GO} build -ldflags="-s -w" -o "${BIN_DIR}/cognitiveos-cli" ./cmd/cognitiveos-cli
echo "  -> cognitiveos-cli built"

echo "Building llama.cpp (vendored in inference)..."
LLAMA_CPP_DIR="${SRC_DIR}/../inference/vendor/llama.cpp"
if [ ! -f "${LLAMA_CPP_DIR}/CMakeLists.txt" ]; then
    echo "  Cloning llama.cpp into vendor/llama.cpp..."
    mkdir -p "$(dirname "${LLAMA_CPP_DIR}")"
    git clone --depth=1 https://github.com/ggerganov/llama.cpp.git "${LLAMA_CPP_DIR}"
fi
cd "${LLAMA_CPP_DIR}"
cmake -B build -DLLAMA_NO_ACCELERATE=1 -DLLAMA_STATIC=1 -DLLAMA_NATIVE=0 \
  -DBUILD_SHARED_LIBS=0 -DLLAMA_BUILD_TESTS=0 \
  -DLLAMA_BUILD_EXAMPLES=0 -DLLAMA_BUILD_SERVER=0
cmake --build build --config Release --target llama -j"$(nproc)"
echo "  -> llama.cpp built"
LLAMA_LIB=$(find build -name "libllama.a" -type f)
if [ -z "${LLAMA_LIB}" ]; then
    echo "  ERROR: libllama.a not found in build/"
    exit 1
fi
echo "  -> Found libraries: ${LLAMA_LIB}"

CGO_LLAMA_LDFLAGS=""
while IFS= read -r lib; do
    libname=$(basename "${lib}" .a | sed 's/^lib//')
    CGO_LLAMA_LDFLAGS="${CGO_LLAMA_LDFLAGS} -l${libname}"
done < <(find build -name "libggml*.a" -type f)

echo "Building inference (coginfer)..."
cd "${SRC_DIR}/../inference"
CGO_ENABLED=1 CGO_LDFLAGS="${CGO_LLAMA_LDFLAGS}" GOOS=linux ${GO} build -tags=cgo -ldflags="-s -w" -o "${BIN_DIR}/cognitiveos-inference" ./cmd/coginfer
echo "  -> cognitiveos-inference built"

echo "Building cograw..."
cd "${SRC_DIR}/../inference"
CGO_ENABLED=1 CGO_LDFLAGS="${CGO_LLAMA_LDFLAGS}" GOOS=linux ${GO} build -tags=cgo -ldflags="-s -w" -o "${BIN_DIR}/cograw" ./cmd/cograw
echo "  -> cograw built"

echo "Building core-mcp-bridges..."
cd "${SRC_DIR}/../core-mcp-bridges"
BRIDGE_BIN_DIR="${BIN_DIR}/bridges"
mkdir -p "${BRIDGE_BIN_DIR}"
for dir in */; do
    bridge=$(basename "${dir}")
    if [ -f "${dir}main.go" ] || [ -f "${dir}go.mod" ] || [ -f "${dir}Makefile" ]; then
        echo "  Building bridge: ${bridge}..."
        CGO_ENABLED=0 GOOS=linux ${GO} build -ldflags="-s -w" -o "${BRIDGE_BIN_DIR}/${bridge}" "./${dir}" || echo "  WARNING: bridge ${bridge} build failed, skipping"
    fi
done
echo "  -> core-mcp-bridges built"

echo ""
echo "All binaries built successfully in ${BIN_DIR}"
