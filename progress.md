# Yapper Progress & Planning

## v0.2 Current State (Done)
- [x] Fn hotkey (single/double tap, long hold)
- [x] Meeting Mode recording
- [x] Custom sound effects
- [x] UI states (Processing, Complete, Smart Options)
- [x] Native menu bar icon
- [x] Draggable panel

---

## v0.3 Priorities

### 1. Preferences Window (Native Apple Style)
Match macOS System Preferences exactly:
- Grouped sections with headers
- Native toggles/sliders
- Footer with version info
- Apply accessibility/system theming

### 2. Permissions & Accessibility
- Detect microphone permission status
- Detect accessibility permission status
- Show clear indicators in menu bar/icon
- Prompt to enable if missing

### 3. Sound Input Selection
- Dropdown to select input device
- Input level visualization during recording
- Save preferred device

---

## Product & Distribution Questions

### Distribution
- [ ] Direct download (DMG)?
- [ ] Homebrew tap?
- [ ] SetApp submission?
- [ ] Mac App Store?

### Paywall Strategy
- [ ] Free tier: Basic dictation (unlimited)
- [ ] Paid tier: Meeting transcription + AI summaries
- [ ] "Bring Your Own Key" - User provides OpenAI/Anthropic API key
- [ ] Optional local: Llama.cpp, Ollama, MLX (privacy-first)

### AI Integration
- [ ] Bring Your Own Key (BYOK) - Enter API key in Settings
- [ ] OpenAI API for summaries (GPT-4o)
- [ ] Anthropic API (Claude)
- [ ] Local model (Llama.cpp/Ollama/MLX) - Optional
- [ ] Meeting notes generation
- [ ] Action item extraction

### Pareto Features (Ranked by 10x Impact)

#### Tier 1: Must Have (10x)
1. ** Meeting Transcription** - Background record + searchable transcript
2. ** One-tap Summaries** - Meeting → bullet points in 1 click

#### Tier 2: Should Have (5x)
3. ** Smart Templates** - dictation → Email/Slack with one tap
4. ** Action Items** - Auto-extract tasks from meetings

#### Tier 3: Nice to Have (2x)
5. ** Multi-language** - Real-time translation
6. ** Private Local AI** - Ollama/MLX integration

### User Experience
- Onboarding flow for permissions
- Tutorial on first launch
- Menu bar status indicator
- Keyboard shortcut hints

---

## Technical Debt

### Tests
- [ ] GestureInterpreterTests passing
- [ ] Add HotkeyManager integration tests

### Build
- [ ] Fix test target in Package.swift

---

## Next Actions
1. Build native Preferences window
2. Add permission checks
3. Create progress.md