#!/bin/sh
set -euo pipefail

usage() {
    echo "Usage: $0 --name <name> --version <version> --binary <path> [--description <desc>] [--author <author>] [--repo <url>] [--issues <url>] [--registry <url>]"
    echo ""
    echo "Builds a .cgp archive from a binary and publishes it to the registry."
    echo ""
    echo "Required:"
    echo "  --name       Package name (e.g., cpm, cognitiveosd)"
    echo "  --version    SemVer version (e.g., 1.0.0)"
    echo "  --binary     Path to the compiled binary"
    echo ""
    echo "Optional:"
    echo "  --description  Human-readable description"
    echo "  --author       Author name/email"
    echo "  --repo         Source repository URL"
    echo "  --issues       Issues URL (reachability-checked by registry)"
    echo "  --registry     Registry URL (default: \$REGISTRY_URL or https://registry-us-all-distros-official.cognitive-os.org/v1)"
    echo "  --token        Auth token (default: \$REGISTRY_TOKEN)"
    echo ""
    echo "Environment:"
    echo "  REGISTRY_URL   Registry base URL (default: https://registry-us-all-distros-official.cognitive-os.org/v1)"
    echo "  REGISTRY_TOKEN Bearer token for registry auth"
    exit 1
}

NAME=""
VERSION=""
BINARY=""
DESCRIPTION=""
AUTHOR=""
REPO=""
ISSUES=""
REGISTRY="${REGISTRY_URL:-https://registry-us-all-distros-official.cognitive-os.org/v1}"
TOKEN="${REGISTRY_TOKEN:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        --name) NAME="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        --binary) BINARY="$2"; shift 2 ;;
        --description) DESCRIPTION="$2"; shift 2 ;;
        --author) AUTHOR="$2"; shift 2 ;;
        --repo) REPO="$2"; shift 2 ;;
        --issues) ISSUES="$2"; shift 2 ;;
        --registry) REGISTRY="$2"; shift 2 ;;
        --token) TOKEN="$2"; shift 2 ;;
        --help|-h) usage ;;
        *) echo "Unknown arg: $1"; usage ;;
    esac
done

if [ -z "$NAME" ] || [ -z "$VERSION" ] || [ -z "$BINARY" ]; then
    echo "ERROR: --name, --version, and --binary are required"
    usage
fi

if [ ! -f "$BINARY" ]; then
    echo "ERROR: binary not found: $BINARY"
    exit 1
fi

if [ -z "$TOKEN" ]; then
    echo "ERROR: REGISTRY_TOKEN not set and --token not provided"
    exit 1
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

ARCHIVE="${WORKDIR}/${NAME}-${VERSION}.cgp"

# Build cognitive.json manifest
cat > "${WORKDIR}/cognitive.json" <<EOF
{
    "name": "$NAME",
    "version": "$VERSION",
    "description": "${DESCRIPTION:-$NAME binary for CognitiveOS}",
    "author": "${AUTHOR:-CognitiveOS Project}"
EOF

if [ -n "$REPO" ]; then
    cat >> "${WORKDIR}/cognitive.json" <<EOF
    ,
    "source": {
        "repository": "$REPO"
EOF
    if [ -n "$ISSUES" ]; then
        cat >> "${WORKDIR}/cognitive.json" <<EOF
        ,
        "issues": "$ISSUES"
EOF
    fi
    cat >> "${WORKDIR}/cognitive.json" <<EOF
    }
EOF
fi

cat >> "${WORKDIR}/cognitive.json" <<EOF
}
EOF

# Create the .cgp archive (tar.gz)
cd "$WORKDIR"
tar czf "$ARCHIVE" \
    --transform="s|^\./||" \
    --transform="s|cognitive\.json|cognitive.json|" \
    --transform="s|$(basename "$BINARY")|bin/$(basename "$BINARY")|" \
    "./cognitive.json" \
    "$BINARY" 2>/dev/null || {
    # Fallback: copy binary and rebuild
    cp "$BINARY" "${WORKDIR}/$(basename "$BINARY")"
    cd "$WORKDIR" && tar czf "$ARCHIVE" cognitive.json "$(basename "$BINARY")"
}
cd - >/dev/null

echo "==> Publishing $NAME v$VERSION to $REGISTRY..."

RESP=$(curl -s -w "\n%{http_code}" -X POST "${REGISTRY}/v1/patches" \
    -H "Authorization: Bearer $TOKEN" \
    -F "name=$NAME" \
    -F "version=$VERSION" \
    -F "description=${DESCRIPTION:-$NAME binary for CognitiveOS}" \
    -F "author=${AUTHOR:-CognitiveOS Project}" \
    ${REPO:+-F "source_repository=$REPO"} \
    ${ISSUES:+-F "source_issues=$ISSUES"} \
    -F "file=@$ARCHIVE;filename=${NAME}-${VERSION}.cgp")

HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "  ✓ Published $NAME v$VERSION (HTTP $HTTP_CODE)"
else
    echo "  ✗ Publish failed (HTTP $HTTP_CODE):"
    echo "$BODY"
    exit 1
fi
