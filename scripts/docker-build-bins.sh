#!/bin/bash
# Build binaries inside a Docker build context.
# Usage: docker-build-bins.sh release|build
#   release — no llama.cpp, inference built with mock backend (CGO_ENABLED=0)
#   build   — full CGo inference with llama.cpp

set -euo pipefail

MODE="${1:?Usage: $0 release|build}"
case "$MODE" in
    release|build) ;;
    *) echo "Unknown mode: $MODE (use release or build)"; exit 1 ;;
esac

REPOS="cpm cognitiveosd cli inference core-mcp-bridges"
mkdir -p /out/bin/bridges

for repo in $REPOS; do
    git clone --depth=1 "https://github.com/CognitiveOS-Project/${repo}.git" "/src/${repo}"
done

if [ "$MODE" = "build" ]; then
    mkdir -p /src/inference/vendor
    git clone --depth=1 https://github.com/ggerganov/llama.cpp.git /src/inference/vendor/llama.cpp
    cd /src/inference/vendor/llama.cpp
    cmake -B build -DLLAMA_NATIVE=0 -DBUILD_SHARED_LIBS=0 \
        -DLLAMA_BUILD_TESTS=0 -DLLAMA_BUILD_EXAMPLES=0 -DLLAMA_BUILD_SERVER=0 \
        -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY="$PWD/build"
    cmake --build build --target llama -j"$(nproc)"
fi

for repo in $REPOS; do
    echo "==> Building $repo..."
    cd "/src/$repo"
    if [ "$repo" = "inference" ] && [ "$MODE" = "release" ]; then
        CGO_ENABLED=0 go build -ldflags="-s -w" -o build/bin/cognitiveos-inference ./cmd/coginfer
        CGO_ENABLED=0 go build -ldflags="-s -w" -o build/bin/cograw ./cmd/cograw
    else
        make build
    fi
    cp -a build/bin/* /out/bin/ 2>/dev/null || true
done
