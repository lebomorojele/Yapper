#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$APP_ROOT/dist"
RELEASES_DIR="${RELEASES_DIR:-$DIST_DIR/sparkle}"
DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX:-https://yapper.party/downloads}"
SPARKLE_TOOL="$APP_ROOT/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
SPARKLE_PRIVATE_KEY="${SPARKLE_PRIVATE_KEY:-}"
SPARKLE_PRIVATE_KEY_FILE="${SPARKLE_PRIVATE_KEY_FILE:-}"

if [[ ! -x "$SPARKLE_TOOL" ]]; then
  swift package --package-path "$APP_ROOT" resolve
fi

if [[ ! -x "$SPARKLE_TOOL" ]]; then
  echo "Could not find Sparkle generate_appcast at $SPARKLE_TOOL" >&2
  exit 1
fi

mkdir -p "$RELEASES_DIR"

latest_dmg="$(find "$DIST_DIR" -maxdepth 1 -name 'Yapper-*.dmg' -type f | sort | tail -n 1)"
if [[ -z "$latest_dmg" ]]; then
  echo "No Yapper DMG found in $DIST_DIR. Run app/scripts/package-dmg.sh first." >&2
  exit 1
fi

cp "$latest_dmg" "$RELEASES_DIR/$(basename "$latest_dmg")"

if [[ -n "$SPARKLE_PRIVATE_KEY" ]]; then
  printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SPARKLE_TOOL" \
    --ed-key-file - \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
    "$RELEASES_DIR"
elif [[ -n "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
  "$SPARKLE_TOOL" \
    --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
    "$RELEASES_DIR"
else
  "$SPARKLE_TOOL" --download-url-prefix "$DOWNLOAD_URL_PREFIX" "$RELEASES_DIR"
fi

cat <<EOF
Generated Sparkle feed:
  $RELEASES_DIR/appcast.xml

Upload:
  - DMG files from $RELEASES_DIR to $DOWNLOAD_URL_PREFIX
  - appcast.xml from $RELEASES_DIR to https://yapper.app/appcast.xml
EOF
