#!/usr/bin/env bash
set -euo pipefail
app_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
binary="$app_root/dist/Yapper.app/Contents/MacOS/Yapper"
owned_pid=""
hidden_build="$app_root/.build-bundle-check"
cleanup() { if [[ -n "$owned_pid" ]]; then kill "$owned_pid" 2>/dev/null || true; wait "$owned_pid" 2>/dev/null || true; fi; if [[ -d "$hidden_build" && ! -e "$app_root/.build" ]]; then mv "$hidden_build" "$app_root/.build"; fi; }
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
if [[ -e "$hidden_build" ]]; then
  echo 'A previous bundle check left its build directory behind. Restore it before retrying.' >&2
  exit 1
fi
# A distributable app must not depend on SwiftPM resources in the build checkout.
if [[ -d "$app_root/.build" ]]; then mv "$app_root/.build" "$hidden_build"; fi
env YAPPER_UI_TEST_MODE=1 YAPPER_VERIFY_AUDIO_PATH="$app_root/Tests/YapperTests/Fixtures/speech.wav" "$binary" > "$app_root/dist/speech-smoke.log" 2>&1 &
owned_pid=$!
for attempt in {1..180}; do
  if ! kill -0 "$owned_pid" 2>/dev/null; then break; fi
  sleep 1
done
if kill -0 "$owned_pid" 2>/dev/null; then
  echo 'Bundled speech verification timed out' >&2
  exit 1
fi
wait "$owned_pid"
owned_pid=""
cat "$app_root/dist/speech-smoke.log"
grep -Fq '[Bundled speech] passed' "$app_root/dist/speech-smoke.log"
echo 'Packaged Yapper launched native screens and transcribed real speech.'
