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

## Text Processing Pipeline (Current)

```
Parakeet STT → HeuristicCleanup (always) → LlamaCpp + Qwen 1.5B GGUF (~1.1 GB) [≥10 words] → Insertion
```

- **HeuristicTextCleanupProcessor** (`Core/TextCleanup/TextCleanupProcessor.swift:20`): Fast path — trims, collapses spaces, capitalizes first letter, appends period. Always runs first.
- **LlamaCppTextCleanupProcessor** (`Core/TextCleanup/TextCleanupProcessor.swift:43`): Optional enhanced cleanup. Shells out to bundled `llama-completion`/`llama-cli` with Qwen2.5-1.5B-Instruct GGUF model. 10s timeout. JSON response parsing. Only runs when transcript ≥ `modelCleanupWordThreshold` (default 10 words).
- **FallbackTextCleanupProcessor** (`Core/TextCleanup/TextCleanupProcessor.swift:182`): Tries LlamaCpp first, falls back to Heuristic on any error.
- **LocalModelManager** (`Core/TextCleanup/LocalModelManager.swift`): Downloads Qwen2.5 1.5B Instruct Q4_K_M (~1.12 GB) from HuggingFace. SHA verification. Stored at `~/Library/Application Support/Yapper/LocalInference/cleanup-model.gguf`.
- **DictationController** (`Features/Dictation/DictationController.swift:134`): Orchestrates the pipeline — heuristic → threshold check → model cleanup → insertion.

## Plan: Replace Qwen 1.5B GGUF with sub-100MB Grammar Correction

### Goal
Replace the 1.12 GB Qwen2.5 1.5B GGUF model with a dedicated grammar correction model under 100MB for faster, lighter on-device cleanup.

### Target Architecture
```
Parakeet STT → HeuristicCleanup (always) → ONNX flan-t5-small INT8 (~50 MB) [≥10 words] → Insertion
```

### Candidate Models
| Model | Size | Approach | Pros | Cons |
|---|---|---|---|---|
| **flan-t5-small ONNX INT8** | ~50 MB | Seq2seq, fine-tuned GEC variants exist | Fast CPU, purpose-built, tiny | Needs ONNX Runtime dep |
| **GECToR ONNX INT8** | ~80 MB | Token-tagging (not seq2seq) | Even faster, GEC-native | Slightly larger, less flexible |
| **SmolLM2-135M GGUF Q4_K_M** | ~80 MB | General LLM | Reuses llama.cpp infra, flexible | Slower than GEC models |
| **LanguageTool** | ~200 MB JAR | Rule-based, no ML | Zero model weights, covers STT errors well | Not neural, larger JAR |

### Recommended: flan-t5-small ONNX INT8
Best balance of size (~50 MB), speed (CPU), and purpose-fit for STT cleanup (homophones, punctuation, agreement).

### Implementation Steps

| Step | Files | Description |
|---|---|---|
| 1. Add ONNX dep | `Package.swift` | Add `onnxruntime-swift` package |
| 2. Create ONNX processor | `Core/TextCleanup/ONNXTextCleanupProcessor.swift` | New `TextCleanupProcessing` impl wrapping ONNX inference |
| 3. Swap model download | `Core/TextCleanup/LocalModelManager.swift` | Change URL, display name, size, SHA to flan-t5-small ONNX |
| 4. Update error handling | `Core/TextCleanup/TextCleanupProcessor.swift` | Add ONNX-specific error cases |
| 5. Remove llama.cpp | `LocalInference/` | Delete bundled llama binaries (no longer needed) |
| 6. Remove LlamaCpp class | `Core/TextCleanup/TextCleanupProcessor.swift` | Delete `LlamaCppTextCleanupProcessor` |
| 7. Update Fallback default | `Core/TextCleanup/TextCleanupProcessor.swift` | Point `FallbackTextCleanupProcessor` default to ONNX |
| 8. Update settings UI | `UI/Settings/SettingsView.swift` | Update labels from "Qwen2.5 1.5B" to flan-t5-small |
| 9. Add tests | `Tests/YapperTests/Core/TextCleanupProcessorTests.swift` | ONNX inference tests + fallback tests |
| 10. Remove old model | App launch cleanup | Detect/offer to remove stale Qwen GGUF if present |

### Key Design Decisions
- **Protocol remains `TextCleanupProcessing`** — no changes to `DictationController` or `AppRuntimeCoordinator`
- **ONNX runs in-process** (vs llama.cpp subprocess) — removes subprocess overhead, faster, simpler
- **Download/verification pattern stays** from `LocalModelManager` — just swap URL and SHA
- **In-process ONNX means no bundled binaries** — `LocalInference/` resource directory goes away entirely
- **Threshold logic unchanged** — heuristic always runs first, model only for ≥N words
