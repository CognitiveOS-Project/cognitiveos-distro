#!/bin/bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 --cgp <path> --download-url <url> [--registry <url>] [--token <token>]

Publishes a .cgp archive to the CognitiveOS notary registry. The registry
stores metadata + checksum only — the archive itself must be hosted elsewhere.

Required:
  --cgp           Path to the .cgp archive (tar.gz with cognitive.json)
  --download-url  Canonical URL where the .cgp is available for download

Optional:
  --registry      Registry URL (default: \$REGISTRY_URL or https://registry-us-all-distros-official.cognitive-os.org/v1)
  --token         Auth token (default: \$REGISTRY_TOKEN)
  --help, -h      Show this help

Environment:
  REGISTRY_URL    Registry base URL
  REGISTRY_TOKEN  Bearer token with publish scope

Examples:
  publish-cgp.sh --cgp ./my-skill-1.0.0.cgp \\
    --download-url https://github.com/owner/repo/releases/v1.0.0/my-skill-1.0.0.cgp

  REGISTRY_TOKEN=cpg_reg_xxx publish-cgp.sh \\
    --cgp ./my-skill-1.0.0.cgp --download-url https://...
EOF
    exit 0
}

CGP=""
DOWNLOAD_URL=""
REGISTRY="${REGISTRY_URL:-https://registry-us-all-distros-official.cognitive-os.org/v1}"
TOKEN="${REGISTRY_TOKEN:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        --cgp) CGP="$2"; shift 2 ;;
        --download-url) DOWNLOAD_URL="$2"; shift 2 ;;
        --registry) REGISTRY="$2"; shift 2 ;;
        --token) TOKEN="$2"; shift 2 ;;
        --help|-h) usage ;;
        *) echo "Unknown arg: $1"; usage ;;
    esac
done

if [ -z "$CGP" ]; then
    echo "ERROR: --cgp is required"
    usage
fi

if [ -z "$DOWNLOAD_URL" ]; then
    echo "ERROR: --download-url is required (notary registry does not host files)"
    usage
fi

if [ ! -f "$CGP" ]; then
    echo "ERROR: archive not found: $CGP"
    exit 1
fi

if [ -z "$TOKEN" ]; then
    echo "ERROR: REGISTRY_TOKEN not set and --token not provided"
    exit 1
fi

# Compute SHA-256 of the archive
SHA256=$(sha256sum "$CGP" | awk '{print $1}')
ARCHIVE_SIZE=$(stat -c%s "$CGP")

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

# Extract cognitive.json from the .cgp archive
tar xzf "$CGP" -C "$WORKDIR" cognitive.json 2>/dev/null || {
    echo "ERROR: cognitive.json not found in $CGP"
    exit 1
}

MANIFEST_JSON=$(cat "$WORKDIR/cognitive.json")

# Build the publish payload
# Extract fields from cognitive.json with jq if available, or fall back to grep/sed
if command -v jq &>/dev/null; then
    NAME=$(echo "$MANIFEST_JSON" | jq -r '.name // empty')
    VERSION=$(echo "$MANIFEST_JSON" | jq -r '.version // empty')
    DESCRIPTION=$(echo "$MANIFEST_JSON" | jq -r '.description // empty')
    AUTHOR=$(echo "$MANIFEST_JSON" | jq -r '.author // empty')
    LICENSE=$(echo "$MANIFEST_JSON" | jq -r '.license // empty')
    SOURCE_REPO=$(echo "$MANIFEST_JSON" | jq -r '.source.repository // empty')
    SOURCE_ISSUES=$(echo "$MANIFEST_JSON" | jq -r '.source.issues // empty')
else
    NAME=$(echo "$MANIFEST_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('name',''))" 2>/dev/null || echo "")
    VERSION=$(echo "$MANIFEST_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('version',''))" 2>/dev/null || echo "")
    DESCRIPTION=$(echo "$MANIFEST_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('description',''))" 2>/dev/null || echo "")
    AUTHOR=$(echo "$MANIFEST_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('author',''))" 2>/dev/null || echo "")
    LICENSE=$(echo "$MANIFEST_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('license',''))" 2>/dev/null || echo "")
    SOURCE_REPO=$(echo "$MANIFEST_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('source',{}).get('repository',''))" 2>/dev/null || echo "")
    SOURCE_ISSUES=$(echo "$MANIFEST_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('source',{}).get('issues',''))" 2>/dev/null || echo "")
fi

if [ -z "$NAME" ] || [ -z "$VERSION" ]; then
    echo "ERROR: cognitive.json missing required fields 'name' or 'version'"
    exit 1
fi

# Build JSON payload
PAYLOAD=$(cat <<ENDJSON
{
  "name": $(echo "$NAME" | jq -Rs '.'),
  "version": $(echo "$VERSION" | jq -Rs '.'),
  "download_url": $(echo "$DOWNLOAD_URL" | jq -Rs '.'),
  "sha256": $(echo "$SHA256" | jq -Rs '.'),
  "manifest": $MANIFEST_JSON
ENDJSON
)

# Add optional fields
[ -n "$DESCRIPTION" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --arg v "$DESCRIPTION" '. + {description: $v}')
[ -n "$AUTHOR" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --arg v "$AUTHOR" '. + {author: $v}')
[ -n "$LICENSE" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --arg v "$LICENSE" '. + {license: $v}')
[ -n "$SOURCE_REPO" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --arg v "$SOURCE_REPO" '. + {source_repository: $v}')
[ -n "$SOURCE_ISSUES" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --arg v "$SOURCE_ISSUES" '. + {source_issues: $v}')

echo "==> Publishing $NAME v$VERSION to $REGISTRY..."
echo "    SHA-256: $SHA256"
echo "    Size: $ARCHIVE_SIZE bytes"
echo "    Download URL: $DOWNLOAD_URL"

RESP=$(curl -s -w "\n%{http_code}" -X POST "${REGISTRY}/patches" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "$PAYLOAD")

HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "  ✓ Published $NAME v$VERSION (HTTP $HTTP_CODE)"
else
    echo "  ✗ Publish failed (HTTP $HTTP_CODE):"
    echo "$BODY"
    exit 1
fi
