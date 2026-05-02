#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOL="$APP_ROOT/.build/artifacts/sparkle/Sparkle/bin/generate_keys"

if [[ ! -x "$TOOL" ]]; then
  swift package --package-path "$APP_ROOT" resolve
fi

if [[ ! -x "$TOOL" ]]; then
  echo "Could not find Sparkle generate_keys at $TOOL" >&2
  exit 1
fi

"$TOOL"
