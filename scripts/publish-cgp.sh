#!/bin/bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 --cgp <path> --download-url <url> [--registry <url>] [--token <token>]

Publishes a .cgp archive to the CognitiveOS notary registry. The registry stores
metadata + checksum only — the archive itself must be hosted elsewhere.

Required:
  --cgp           Path to the .cgp archive (tar.gz with cognitive.json)
  --download-url  Canonical URL where the .cgp is available for download

Optional:
  --registry      Registry URL (default: \$REGISTRY_URL)
  --token         Auth token (default: \$REGISTRY_TOKEN)
  --help, -h      Show this help

Environment:
  REGISTRY_URL    Registry base URL
  REGISTRY_TOKEN  Bearer token with publish scope
EOF
    exit 0
}

CGP=""
DOWNLOAD_URL=""
REGISTRY="${REGISTRY_URL:-https://registry-us-all-distros-official.cognitive-os.org/v1}"
TOKEN="${REGISTRY_TOKEN:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        --cgp)          CGP="$2"; shift 2 ;;
        --download-url) DOWNLOAD_URL="$2"; shift 2 ;;
        --registry)     REGISTRY="$2"; shift 2 ;;
        --token)        TOKEN="$2"; shift 2 ;;
        --help|-h)      usage ;;
        *) echo "Unknown arg: $1"; usage ;;
    esac
done

[ -n "$CGP" ] || { echo "ERROR: --cgp is required"; usage; }
[ -n "$DOWNLOAD_URL" ] || { echo "ERROR: --download-url is required"; usage; }
[ -f "$CGP" ] || { echo "ERROR: archive not found: $CGP"; exit 1; }
[ -n "$TOKEN" ] || { echo "ERROR: REGISTRY_TOKEN not set and --token not provided"; exit 1; }

SHA256=$(sha256sum "$CGP" | awk '{print $1}')

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

tar xzf "$CGP" -C "$WORKDIR" cognitive.json 2>/dev/null || {
    echo "ERROR: cognitive.json not found in $CGP"; exit 1;
}

MANIFEST_JSON=$(cat "$WORKDIR/cognitive.json")

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required"; exit 1; }

NAME=$(echo "$MANIFEST_JSON" | jq -r '.name // empty')
VERSION=$(echo "$MANIFEST_JSON" | jq -r '.version // empty')
[ -n "$NAME" ] && [ -n "$VERSION" ] || { echo "ERROR: cognitive.json missing 'name' or 'version'"; exit 1; }

PAYLOAD=$(jq -n --arg name "$NAME" --arg ver "$VERSION" --arg url "$DOWNLOAD_URL" \
    --arg sha256 "$SHA256" --argjson manifest "$MANIFEST_JSON" '{
    name: $name,
    version: $ver,
    download_url: $url,
    sha256: $sha256,
    manifest: $manifest
}')

DESCRIPTION=$(echo "$MANIFEST_JSON" | jq -r '.description // empty')
AUTHOR=$(echo "$MANIFEST_JSON" | jq -r '.author // empty')
LICENSE=$(echo "$MANIFEST_JSON" | jq -r '.license // empty')
SOURCE_REPO=$(echo "$MANIFEST_JSON" | jq -r '.source.repository // empty')
SOURCE_ISSUES=$(echo "$MANIFEST_JSON" | jq -r '.source.issues // empty')

[ -n "$DESCRIPTION" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --arg v "$DESCRIPTION" '. + {description: $v}')
[ -n "$AUTHOR" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --arg v "$AUTHOR" '. + {author: $v}')
[ -n "$LICENSE" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --arg v "$LICENSE" '. + {license: $v}')
[ -n "$SOURCE_REPO" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --arg v "$SOURCE_REPO" '. + {source_repository: $v}')
[ -n "$SOURCE_ISSUES" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --arg v "$SOURCE_ISSUES" '. + {source_issues: $v}')

RESP=$(curl -s -w "\n%{http_code}" -X POST "${REGISTRY}/patches" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "$PAYLOAD")

HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "  Published $NAME v$VERSION (HTTP $HTTP_CODE)"
else
    echo "  Publish failed (HTTP $HTTP_CODE): $BODY"
    exit 1
fi
