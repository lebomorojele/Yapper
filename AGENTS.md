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
- `Yapper/App/AppRuntimeCoordinator.swift` - Runtime orchestration, permissions, hotkey state, session lifecycle
- `Yapper/App/HistoryWindowController.swift` - Shared transcript history window
- `Yapper/App/SettingsWindowController.swift` - Preferences window
- `Yapper/Core/History/HistoryStore.swift` - Persistent shared history store and transcript export
- `Yapper/Core/Audio/SoundManager.swift` - Sound playback (start.mp3, success.mp3, fail.mp3)
- `Yapper/Features/Dictation/DictationController.swift` - Recording/transcription session controller
- `Yapper/UI/FloatingPanel/PillContentView.swift` - Recording states, Smart Options UI
- `Yapper/UI/History/HistoryView.swift` - Shared dictation and meeting history UI
- `Yapper/UI/Settings/SettingsView.swift` - Preferences view (GENERAL, AUDIO, MEETING, AI & KEYS, KEYBOARD, ABOUT)

## Features

- **Hotkeys:** Single tap (start/stop), double tap (meeting mode), hold (continuous)
- **Sound effects:** start.mp3 on recording start, success.mp3 on completion, fail.mp3 on error
- **Smart Options:** Slack, Chat, Email, Prompt, or keep original
- **History:** Shared transcript history for dictation and meeting sessions
- **Preferences:** Native Tahoe-style preferences with live audio metering and provider-aware AI settings
