#!/bin/bash
# Build all distro binaries inside a Docker build context.
set -euo pipefail

REPOS="cpm cognitiveosd cli inference core-mcp-bridges"
mkdir -p /out/bin/bridges

for repo in $REPOS; do
    git clone --depth=1 "https://github.com/CognitiveOS-Project/${repo}.git" "/src/${repo}"
done

mkdir -p /src/inference/vendor
git clone --depth=1 https://github.com/ggerganov/llama.cpp.git /src/inference/vendor/llama.cpp
cd /src/inference/vendor/llama.cpp
cmake -B build -DLLAMA_NATIVE=0 -DBUILD_SHARED_LIBS=0 \
    -DLLAMA_BUILD_TESTS=0 -DLLAMA_BUILD_EXAMPLES=0 -DLLAMA_BUILD_SERVER=0 \
    -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY="$PWD/build"
cmake --build build --target llama -j"$(nproc)"

for repo in $REPOS; do
    echo "==> Building $repo..."
    cd "/src/$repo"
    make build
    cp -a build/bin/* /out/bin/ 2>/dev/null || true
done
