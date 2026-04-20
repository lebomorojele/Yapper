# Yapper Progress & Planning

## v0.3.x Hotfix (In Progress)
- [x] Fix single/double tap not starting audio capture
- [x] Fix modelReady never set to true 
- [x] Fix Ready state UI layout (centered text)
- [x] Fix Preferences panel (Meeting tab, navigation, sidebar width)
- [x] Audio device selection wired to settings (System Default option)
- [x] Replace legacy smart options UI with new pill-only surfaces
- [x] Restore visible completion / clipboard completion pills
- [x] Rebuild preferences window with native Tahoe-style sections
- [x] Fix pill proportions and waveform animation to match design reference
- [ ] Replace hybrid pill chrome with 1:1 Dynamic Island-style SwiftUI port
- [x] Stabilize pill transitions and add keyboard shortcuts for smart mode selection
- [ ] Remove sidebar toggle / "hide menu" header control from preferences
- [ ] Route long-press meeting mode through real transcription output path
- [x] Add Hex-inspired runtime coordinator for hotkeys, permissions, and transient app state
- [x] Refactor hotkey monitoring with explicit status and permission-driven recovery
- [x] Separate runtime permission/model readiness state from persisted settings
- [x] Add focused tests for hotkey recovery and meeting-mode silence behavior

---

## v0.4 Production Pass 1 (In Progress)
- [x] Replace decorative pill waveform with live audio-meter-driven bars
- [x] Introduce session-oriented recording/runtime types for dictation, smart mode, and meetings
- [x] Persist transcript-first meeting/dictation history in a dedicated history store
- [x] Add shared history window with type tags and manual AI follow-up actions
- [x] Route meeting completion into history/export instead of text insertion
- [x] Improve pill polish with centered live transcript and canceled-state feedback
- [x] Finish phase-2 recording/transcription cleanup across all exit paths
- [x] Patch and expand tests for new session/history flows
- [x] Re-run release build and SwiftPM tests cleanly
- [x] Split SwiftPM tests from app-hosted UI tests so `swift test` can stay reliable
- [x] Add history quick actions and transcript export coverage
- [x] Clean low-risk runtime warnings in transcriber and sound playback
- [x] Capture a real SwiftPM coverage baseline for app-owned code
- [x] Add a focused manual hotkey QA checklist

---

## v0.3 Priorities (Done)
- [x] Native Preferences Window
- [x] Permissions & Accessibility status
- [x] Sound Input Selection & Level Meter
- [x] Polish: State Transitions (Ready/Processing/Complete)
- [x] E2E Integration Testing Suite (Mock-based)

---

## v0.4 Planning (Future)

### 1. Features
- [x] Meeting transcription persistence
- [ ] One-tap summaries (LLM integration)
- [ ] Action item extraction

### 2. Infrastructure
- [ ] Expand E2E test suite to cover GestureInterpreter
- [ ] Add HotkeyManager integration tests

---

## Next Actions
1. Run the hotkey QA checklist against the latest release binary
2. Refine shared history UX and decide how first-class summary/action-item actions should be
3. Raise logic-layer coverage in hotkey, dictation, and insertion paths
4. Expand beyond SwiftPM unit/integration coverage into higher-level app-hosted scenarios
