# Yapper - macOS Menu Bar Voice Dictation App

## Setup

### Build the app

```bash
swift build -c release
```

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
- `Yapper/App/SettingsWindowController.swift` - Preferences window
- `Yapper/Core/Audio/SoundManager.swift` - Sound playback (start.mp3, success.mp3, fail.mp3)
- `Yapper/UI/FloatingPanel/PillContentView.swift` - Recording states, Smart Options UI
- `Yapper/UI/Settings/SettingsView.swift` - Preferences view (GENERAL, AUDIO, ABOUT)

## Features

- **Hotkeys:** Single tap (start/stop), double tap (meeting mode), hold (continuous)
- **Sound effects:** start.mp3 on recording start, success.mp3 on completion, fail.mp3 on error
- **Smart Options:** Keep original, Change to formal, Fix grammar
- **Preferences:** General settings, Audio input selection, About section