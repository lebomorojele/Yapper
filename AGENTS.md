# Yapper - macOS Menu Bar Voice Dictation App

## Setup

### App workspace

The macOS app lives in `app/`. Run SwiftPM commands from that directory.

### Build the app

```bash
cd app
swift build -c release
```

### Run unit and integration tests

```bash
cd app
swift test
```

### Run UI tests

UI tests are intentionally not part of the SwiftPM `swift test` workflow anymore.
Run them from the Xcode project or an Xcode-aware destination so they have a real app host.

### Run the app

**IMPORTANT:** Run the binary directly, NOT via Xcode debugger or shell:

```bash
cd app
nohup ./.build/release/Yapper > /dev/null 2>&1 &
```

### Why nohup?

Hotkeys don't work when running via Xcode debugger or shell because they run in "keys-off mode". Running the compiled binary directly with `nohup` avoids this issue.

## Common Pitfalls

### Hotkeys not working

- **Cause:** Running via Xcode debugger or shell
- **Fix:** Run the binary directly from `app/`: `nohup ./.build/release/Yapper > /dev/null 2>&1 &`

### Code changes not appearing

- **Cause:** Build caching
- **Fix:** Clean rebuild from `app/`: `rm -rf .build && swift build -c release`

### Old code showing in UI

- **Cause:** Build cache not invalidated
- **Fix:** `rm -rf app/.build` before rebuilding

## Distribution

### Build a local DMG

```bash
ALLOW_PLACEHOLDER_SPARKLE_KEY=1 app/scripts/package-dmg.sh
```

### Build a release DMG

```bash
export SPARKLE_PUBLIC_ED_KEY="..."
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="yapper-notary"
app/scripts/package-dmg.sh
```

### Generate a Sparkle appcast

```bash
export DOWNLOAD_URL_PREFIX="https://yapper.app/downloads"
app/scripts/generate-appcast.sh
```

## Project Structure

- `app/Yapper/App/AppDelegate.swift` - Main app logic, hotkey handling, menu bar
- `app/Yapper/App/AppRuntimeCoordinator.swift` - Runtime orchestration, permissions, hotkey state, dictation lifecycle
- `app/Yapper/App/SparkleUpdateController.swift` - Sparkle updater lifecycle and manual update checks
- `app/Yapper/App/SettingsWindowController.swift` - Preferences window
- `app/Yapper/Core/Audio/SoundManager.swift` - Sound playback (start.mp3, success.mp3, system error fallback)
- `app/Yapper/Core/TextCleanup/TextCleanupProcessor.swift` - Heuristic and local llama.cpp transcript cleanup
- `app/Yapper/Features/Dictation/DictationController.swift` - Recording/transcription session controller
- `app/Yapper/LocalInference/` - Bundled llama.cpp binaries for optional enhanced cleanup
- `app/Yapper/UI/FloatingPanel/PillContentView.swift` - Recording, processing, inserted/copied, canceled, and failed states
- `app/Yapper/UI/Settings/SettingsView.swift` - Preferences view for insertion, audio, keyboard, local cleanup, and about
- `website/` - Launch website

## Features

- **Hotkey:** Globe/Fn single tap toggles dictation start/stop
- **Sound effects:** start.mp3 on listening start, success.mp3 on inserted/copied completion, system fallback on error
- **Local cleanup:** Short transcripts use deterministic punctuation/casing; longer transcripts can use the optional downloaded GGUF model
- **Text insertion:** Accessibility insertion by default, with clipboard fallback mode available in settings
- **Preferences:** Native Tahoe-style preferences with live audio metering, insertion controls, keyboard notes, and local cleanup settings

## Removed in v2

- Meeting mode
- Smart mode picker and transforms
- Cloud AI provider settings
- Transcript history window and export
- Design catalog/demo surfaces
