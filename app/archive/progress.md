# Yapper v2 Progress

## Phase 0: Simplify to Core Dictation
- [x] Collapse runtime to one tap-toggle dictation flow
- [x] Remove meeting mode, smart modes, history, transcript export, and cloud AI surfaces
- [x] Keep Parakeet transcription, floating pebble feedback, and focused text insertion
- [x] Reduce settings to insertion, audio, keyboard, and about
- [ ] Validate release binary with manual hotkey QA

## Phase 1: Local Cleanup Engine
- [x] Add `TextCleanupProcessing` abstraction after Parakeet final text and before insertion
- [x] Add deterministic heuristic punctuation/casing fallback
- [x] Add llama.cpp CLI adapter with strict cleanup prompt and raw-text fallback
- [x] Bundle macOS arm64 `llama-cli` and `llama-completion`
- [x] Download Qwen2.5 1.5B Instruct Q4_K_M GGUF on opt-in instead of bundling it

## Phase 2: Bundle + Performance Polish
- [ ] Measure cleanup latency on short dictation snippets
- [ ] Tune llama.cpp timeout and token limit
- [ ] Decide whether heuristic cleanup remains user-visible or becomes internal fallback only
- [ ] Run final release build and manual app QA

## Deferred / Explicitly Cut
- Meeting mode
- Smart mode picker and mode transforms
- Cloud AI provider settings
- Transcript history window and export
- Design catalog/demo surfaces
- Website work
