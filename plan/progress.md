# Plan: Replace Qwen 1.5B GGUF with Sub-100MB Grammar Correction

## Status: Draft — not yet implemented

## Goal
Replace the 1.12 GB Qwen2.5 1.5B GGUF model with a dedicated grammar correction model under 100MB for faster, lighter on-device cleanup.

## Current Architecture

```
Parakeet STT → HeuristicCleanup (always) → LlamaCpp + Qwen 1.5B GGUF (~1.1 GB) [≥10 words] → Insertion
```

## Target Architecture

```
Parakeet STT → HeuristicCleanup (always) → ONNX flan-t5-small INT8 (~50 MB) [≥10 words] → Insertion
```

## Candidate Models

| Model | Size | Approach | Pros | Cons |
|---|---|---|---|---|
| **flan-t5-small ONNX INT8** | ~50 MB | Seq2seq, fine-tuned GEC variants exist | Fast CPU, purpose-built, tiny | Needs ONNX Runtime dep |
| **GECToR ONNX INT8** | ~80 MB | Token-tagging (not seq2seq) | Even faster, GEC-native | Slightly larger, less flexible |
| **SmolLM2-135M GGUF Q4_K_M** | ~80 MB | General LLM | Reuses llama.cpp infra, flexible | Slower than GEC models |
| **LanguageTool** | ~200 MB JAR | Rule-based, no ML | Zero model weights, covers STT errors well | Not neural, larger JAR |

## Recommended: flan-t5-small ONNX INT8
Best balance of size (~50 MB), speed (CPU), and purpose-fit for STT cleanup (homophones, punctuation, agreement).

## Implementation Steps

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

## Key Design Decisions

- **Protocol remains `TextCleanupProcessing`** — no changes to `DictationController` or `AppRuntimeCoordinator`
- **ONNX runs in-process** (vs llama.cpp subprocess) — removes subprocess overhead, faster, simpler
- **Download/verification pattern stays** from `LocalModelManager` — just swap URL and SHA
- **In-process ONNX means no bundled binaries** — `LocalInference/` resource directory goes away entirely
- **Threshold logic unchanged** — heuristic always runs first, model only for ≥N words

## Notes

- Explored and documented in conversation on 2026-05-03
- AGENTS.md has been updated in parallel with this file
- All relevant source files were read and analyzed before writing this plan
