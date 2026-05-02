# Yapper - macOS Menu Bar Voice Dictation App

## Setup

### Build the app

```bash
swift build -c release
```

### Run unit and integration tests

```bash
swift test
```

### Run UI tests

UI tests are intentionally not part of the SwiftPM `swift test` workflow anymore.
Run them from the Xcode project or an Xcode-aware destination so they have a real app host.

### Run the app

**IMPORTANT:** Run the binary directly, NOT via Xcode debugger or shell:

```bash
nohup ./.build/release/Yapper > /dev/null 2>&1 &
```

### Why nohup?

Hotkeys don't work when running via Xcode debugger or shell because they run in "keys-off mode". Running the compiled binary directly with `nohup` avoids this issue.

## Common Pitfalls

### Hotkeys not working

- **Cause:** Running via Xcode debugger or shell
- **Fix:** Run the binary directly: `nohup ./.build/release/Yapper > /dev/null 2>&1 &`

### Code changes not appearing

- **Cause:** Build caching
- **Fix:** Clean rebuild: `rm -rf .build && swift build -c release`

### Old code showing in UI

- **Cause:** Build cache not invalidated
- **Fix:** `rm -rf .build` before rebuilding

## Project Structure

- `Yapper/App/AppDelegate.swift` - Main app logic, hotkey handling, menu bar
- `Yapper/App/AppRuntimeCoordinator.swift` - Runtime orchestration, permissions, hotkey state, dictation lifecycle
- `Yapper/App/SettingsWindowController.swift` - Preferences window
- `Yapper/Core/Audio/SoundManager.swift` - Sound playback (start.mp3, success.mp3, system error fallback)
- `Yapper/Core/TextCleanup/TextCleanupProcessor.swift` - Heuristic and local llama.cpp transcript cleanup
- `Yapper/Features/Dictation/DictationController.swift` - Recording/transcription session controller
- `Yapper/LocalInference/` - Bundled llama.cpp binaries for optional enhanced cleanup
- `Yapper/UI/FloatingPanel/PillContentView.swift` - Recording, processing, inserted/copied, canceled, and failed states
- `Yapper/UI/Settings/SettingsView.swift` - Preferences view for insertion, audio, keyboard, local cleanup, and about

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
