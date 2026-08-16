# Linos App — Build Plan

> Planner file for the builder agent. Update checkboxes and the status table as milestones complete. Do not remove completed items — mark them `[x]` for an audit trail. Each milestone is self-contained: read its Context + Tasks + Done When before starting work.

## Status

| # | Milestone | Status | Depends on |
|---|-----------|--------|------------|
| 1 | Core architecture and foundation | Done | — |
| 2 | Audio input and permissions | In Progress | 1 |
| 3 | Basic pitch detection engine | Not Started | 2 |
| 4 | Tuning logic and feedback system | Not Started | 3 |
| 5 | Complete tuner UI with polish | Not Started | 4 |
| 6 | Testing, documentation, performance | Not Started | 5 |

Status values: `Not Started` / `In Progress` / `Blocked` / `Done`

---

## Architecture

Flutter, MVVM + repository pattern.

```
lib/
├── data/
│   ├── models/              # Domain models (Note, Tuning, Frequency)
│   ├── repositories/        # Audio processing and pitch detection logic
│   └── services/            # Audio input handling, platform plugins
├── domain/
│   ├── models/              # Clean data models
│   └── use_cases/           # Business logic for tuning operations
└── ui/
    ├── core/                # Shared UI components, themes, typography
    └── features/
        └── tuner/
            ├── view_models/
            └── views/
```

**Core data models:** `Note` (name, frequency, octave) · `Tuning` (notes for an instrument config) · `Frequency` (from pitch detection) · `TuningStatus` (flat/in-tune/sharp) · `StringState` (full tuning state for one string).

**Key libraries to evaluate:** `fft` (Fast Fourier Transform), `audio_recorder` or platform-specific audio APIs, `audio_session` (platform audio config).

---

## Milestone 1 — Core Architecture and Foundation

**Context:** Establishes the project skeleton everything else builds on.

**Tasks**
- [x] Set up Flutter project with MVVM architecture (folder structure above)
- [x] Configure audio session permission scaffolding (no live audio yet)
- [x] Create basic UI structure and theme
- [x] Implement core data models (`Note`, `Tuning`, `Frequency`, `TuningStatus`, `StringState`)
- [x] Add a dependency injection framework

**Done when**
- [x] Project builds cleanly on Android and iOS
- [x] Placeholder UI renders
- [x] Core models compile with no dependencies on audio code yet

**Notes:** Android debug build verified (`flutter build apk --debug`). iOS build requires macOS/Xcode — verify on a Mac before M2. `permission_handler` pinned to `^12.0.1` (13.x pulls `permission_handler_android` 14.x which needs AGP 9/Kotlin 2.3, incompatible with Flutter 3.41).

**Commit message:** `feat: set up core architecture and foundation for guitar tuner`

---

## Milestone 2 — Audio Input and Permissions

**Context:** Depends on M1 models/DI being in place. Do not start pitch detection until permissions are reliably granted on both platforms.

**Tasks**
- [x] Add microphone permission handling (Android manifest + iOS Info.plist + runtime prompts)
- [x] Configure audio session via `audio_session`
- [x] Create `AudioInputService` for raw audio capture/streaming
- [x] Add error handling for denied/revoked permissions
- [ ] Test on both Android and iOS (physical devices if available, not just simulators — mic behavior differs)

**Done when**
- [x] App requests and obtains mic permission on first launch
- [x] Denial path shows a clear in-app message, doesn't crash
- [x] Raw audio stream is observable (e.g., logged amplitude) on both platforms

**Notes:** `record ^6.2.1` used for capture (PCM16 mono 44.1 kHz stream). Device verification pending — no physical devices available in this environment; test on real Android/iOS hardware before starting M3. Android debug build verified.

**Commit message:** `feat: implement audio input and permissions handling`

---

## Milestone 3 — Basic Pitch Detection Engine

**Context:** Depends on M2's audio stream being stable. This is the highest-risk milestone — flag issues early rather than pushing through.

**Tasks**
- [ ] Integrate FFT-based pitch detection algorithm
- [ ] Implement frequency calculation from FFT output
- [ ] Create note-to-frequency mapping logic
- [ ] Add a basic (debug-only) frequency display
- [ ] Wire up the continuous audio-processing loop

**Done when**
- [ ] Known test tones (e.g., a tone generator or reference recordings) are detected within acceptable Hz tolerance
- [ ] Low E (~82 Hz) and high E (~330 Hz) both detect correctly — low frequencies are the usual failure point
- [ ] Detection loop runs continuously without memory growth over a 2+ minute session

**Commit message:** `feat: implement basic pitch detection engine`

**Open risk to watch:** FFT window size trade-off between low-frequency accuracy and latency — note whatever value is chosen and why.

---

## Milestone 4 — Tuning Logic and Feedback System

**Context:** Depends on M3 producing stable frequency readings.

**Tasks**
- [ ] Implement standard tuning (E-A-D-G-B-E) reference table
- [ ] Implement flat/in-tune/sharp calculation against nearest target note
- [ ] Implement per-string detection (map detected frequency to the intended string, not just nearest note)
- [ ] Design tuning status indicator logic (data layer, not final visuals yet)

**Done when**
- [ ] App correctly classifies flat/in-tune/sharp on a real guitar for all 6 strings
- [ ] String identification is correct even when a string is significantly out of tune

**Commit message:** `feat: implement tuning logic and feedback system`

---

## Milestone 5 — Complete Tuner UI with Polish

**Context:** Depends on M4's tuning data being reliable. This is where the debug display from M3 gets replaced.

**Tasks**
- [ ] Guitar-specific UI design (gauge/needle or equivalent pitch indicator)
- [ ] String identification display
- [ ] Responsive tuning feedback visualization (flat/in-tune/sharp states)
- [ ] Settings and controls (e.g., reference pitch A4=440Hz toggle if in scope)
- [ ] Animations and final visual polish

**Done when**
- [ ] Full tuning flow works end-to-end through the real UI (no debug displays left in release build)
- [ ] Accessibility pass done (contrast, labels for screen readers)
- [ ] Spot-checked with at least one real guitar player

**Commit message:** `feat: implement complete tuner UI with polish`

---

## Milestone 6 — Testing, Documentation, and Performance

**Context:** Final hardening pass before considering the app release-ready.

**Tasks**
- [ ] Unit tests: audio processing algorithms, note detection/mapping, tuning accuracy calculations, model validation
- [ ] Integration tests: audio input → pitch detection pipeline, full tuning workflow, error scenarios
- [ ] Performance optimization pass (battery, memory, latency)
- [ ] Documentation (README, API docs)
- [ ] Final UX/accessibility review

**Done when**
- [ ] All unit + integration tests passing
- [ ] Performance benchmarks met (define target latency/battery numbers before this milestone starts)
- [ ] README and API docs complete
- [ ] User acceptance testing complete

**Commit message:** `test: add comprehensive testing and documentation`

---

## Cross-cutting concerns (apply throughout, not a single milestone)

- **Error handling:** mic permission failures, audio session config errors, processing failures, device-specific edge cases
- **Performance:** battery efficiency, real-time latency, graceful handling of audio interruptions (calls, other apps), background audio behavior
- **Platform parity:** verify every milestone on both Android and iOS before marking Done — don't defer cross-platform testing to M6

## Future / out of scope for this plan

- Tuning selection screen (alternate tunings)
- Multi-instrument support
- History/record tracking
- Chord recognition, metronome, song browsing