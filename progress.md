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
- [ ] Remove sidebar toggle / "hide menu" header control from preferences
- [ ] Route long-press meeting mode through real transcription output path

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
- [ ] Meeting transcription persistence
- [ ] One-tap summaries (LLM integration)
- [ ] Action item extraction

### 2. Infrastructure
- [ ] Expand E2E test suite to cover GestureInterpreter
- [ ] Add HotkeyManager integration tests

---

## Next Actions
1. Retest single-tap, double-tap, and long-press flows after the latest layout fixes
2. Start second pass on Hex-inspired production hardening
3. Capture any remaining visual polish issues from the new screenshots
