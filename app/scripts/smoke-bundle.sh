#!/usr/bin/env bash
set -euo pipefail
app_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
binary="$app_root/dist/Yapper.app/Contents/MacOS/Yapper"
owned_pid=""
cleanup() { if [[ -n "$owned_pid" ]]; then kill "$owned_pid" 2>/dev/null || true; wait "$owned_pid" 2>/dev/null || true; fi; }
trap cleanup EXIT
for screen in SETTINGS WELCOME; do
  name="$(printf '%s' "$screen" | tr '[:upper:]' '[:lower:]')"
  env YAPPER_UI_TEST_MODE=1 "YAPPER_OPEN_${screen}_ON_LAUNCH=1" "$binary" > "$app_root/dist/$name-smoke.log" 2>&1 &
  owned_pid=$!
  sleep 5
  if ! kill -0 "$owned_pid" 2>/dev/null; then
    cat "$app_root/dist/$name-smoke.log" >&2
    echo "Packaged app exited before displaying $name" >&2
    exit 1
  fi
  screencapture -x "$app_root/dist/$name.png"
  test -s "$app_root/dist/$name.png"
  cleanup
  owned_pid=""
done
echo 'Packaged Yapper launched for settings and welcome. Inspect the captured screens.'
