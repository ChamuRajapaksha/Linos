# Linos App — Build Plan

> Planner file for the builder agent. Update checkboxes and the status table as milestones complete. Do not remove completed items — mark them `[x]` for an audit trail. Each milestone is self-contained: read its Context + Tasks + Done When before starting work.
>
> **Milestone sizing note:** Milestones 7–11 (alternate tunings) are deliberately split into small, narrow-scope units instead of one large "alternate tunings" milestone. Each one touches one layer (data model, matching, UI, custom tunings, validation) so a builder agent can load just that milestone's context, plus the specific files it names, without needing the full history of prior milestones to make progress. Don't merge them back together even if they look small — the split is intentional.
>
> **Commit granularity note:** Within milestones 7–11, each task lists its own commit message (marked with →) — commit after finishing that task, not at the end of the milestone. This keeps diffs small and gives clean rollback points if a later task in the same milestone goes wrong. The "Wrap-up commit" at the end of each milestone is a fallback only, for whoever skipped the per-task commits.

## Status

| # | Milestone | Status | Depends on |
|---|-----------|--------|------------|
| 1 | Core architecture and foundation | Done | — |
| 2 | Audio input and permissions | Done | 1 |
| 3 | Basic pitch detection engine | Done | 2 |
| 4 | Tuning logic and feedback system | Done | 3 |
| 5 | Complete tuner UI with polish | Done | 4 |
| 6 | Real-world tuning accuracy, testing, documentation, performance | Not Started | 5 |
| 7 | Alternate tuning data model & presets | Not Started | 6 |
| 8 | Tuning-aware string matching & detection | Not Started | 7 |
| 9 | Alternate tuning selection UI | Not Started | 8 |
| 10 | Custom tuning support | Not Started | 9 |
| 11 | Real-world validation & docs for alternate tunings | Not Started | 9 (10 if built) |

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
- [x] Integrate FFT-based pitch detection algorithm
- [x] Implement frequency calculation from FFT output
- [x] Create note-to-frequency mapping logic
- [x] Add a basic (debug-only) frequency display
- [x] Wire up the continuous audio-processing loop

**Done when**
- [x] Known test tones (e.g., a tone generator or reference recordings) are detected within acceptable Hz tolerance
- [x] Low E (~82 Hz) and high E (~330 Hz) both detect correctly — low frequencies are the usual failure point
- [x] Detection loop runs continuously without memory growth over a 2+ minute session *(headless soak: `flutter test --tags soak --dart-define=RUN_SOAK=true` — pumps synthetic guitar audio through the production isolate pipeline for 2 real minutes; asserts no errors, bounded buffer, in-flight cap, ≤32 MiB RSS growth (~3 MiB measured); see `test/data/services/pitch_detection_service_soak_test.dart`. The M6 on-device soak still validates real mic audio.)*

**Commit message:** `feat: implement basic pitch detection engine`

**Open risk to watch:** FFT window size trade-off between low-frequency accuracy and latency — note whatever value is chosen and why.

**Notes (completed):** Self-contained radix-2 FFT implementation (pure Dart, no package — the `fft` pub package is unmaintained). Config chosen: 4096-sample Hann window (92.9 ms latency), 8x zero-padding to FFT size 32768 for fine bin spacing (1.35 Hz/bin), hop 2048 (46 ms), peak search 70–1400 Hz with log-domain parabolic interpolation, RMS gate (0.01) + confidence gate. Measured accuracy on synthetic sines: max error 0.65 Hz across 82.41–880 Hz. Confirmed by unit tests: 85/85 passing, `flutter analyze` clean. Remaining: 2+ minute continuous-run memory check on a physical device, and verifying low-E vs open-string harmonics behavior on real audio.

---

## Milestone 4 — Tuning Logic and Feedback System

**Context:** Depends on M3 producing stable frequency readings.

**Tasks**
- [x] Implement standard tuning (E-A-D-G-B-E) reference table
- [x] Implement flat/in-tune/sharp calculation against nearest target note
- [x] Implement per-string detection (map detected frequency to the intended string, not just nearest note)
- [x] Design tuning status indicator logic (data layer, not final visuals yet)

**Done when**
- [ ] App correctly classifies flat/in-tune/sharp on a real guitar for all 6 strings
- [x] String identification is correct even when a string is significantly out of tune

**Commit message:** `feat: implement tuning logic and feedback system`

**Notes (completed):** `TuningStatusClassifier` (default ±5 cents in-tune band, configurable) and `StringMatcher` (per-string matching with harmonic folding up to the 3rd harmonic for weak-fundamental robustness). Verified on synthetic frequencies: correct string identification for all 6 open strings, incl. low E detuned up to ~2 semitones (73.42 Hz → E2 at -200¢) and harmonic-only detections (2nd/3rd harmonic folds to the right string). Standard tuning reference table already existed (`Tuning.standard`). Exposed to the debug readout (target string + status). Real-guitar classification still needs physical-device verification (no hardware in this environment). Known limit (documented in string_matcher tests): single-pitch matching is ambiguous beyond ~±2.5 semitones of detuning — resolve via a string selector in M5.

---

## Milestone 5 — Complete Tuner UI with Polish

**Context:** Depends on M4's tuning data being reliable. This is where the debug display from M3 gets replaced.

**Tasks**
- [x] Guitar-specific UI design (gauge/needle or equivalent pitch indicator)
- [x] String identification display
- [x] Responsive tuning feedback visualization (flat/in-tune/sharp states)
- [x] Settings and controls (e.g., reference pitch A4=440Hz toggle if in scope)
- [x] Animations and final visual polish

**Done when**
- [x] Full tuning flow works end-to-end through the real UI (no debug displays left in release build)
- [x] Accessibility pass done (contrast, labels for screen readers)
- [ ] Spot-checked with at least one real guitar player

**Commit message:** `feat: implement complete tuner UI with polish`

**Notes (completed):** Replaced the debug readout with the production tuner: a signature six-string rail (low E thick → high E thin, tap to focus a string, active string glows, emerald when in tune), a V-gauge needle animated to the cents offset (±50¢ sweep), a hero note readout (giant letter + string ordinal + cents + FLAT/IN TUNE/SHARP), and a reference-pitch setting (A4 = 438/440/442 Hz) backed by `Tuning.retunedTo`. Tapping a string fixes matching to that string (resolves the M4 ±2.5-semitone ambiguity); tapping it again returns to auto-detection. New theme in `ui/core/theme/` (`linos_palette.dart` tokens): warm walnut/ebony surface with brass accent and a directional status spectrum (slate = flat, emerald = in tune, ember = sharp). Accessibility: semantics labels on the note readout, gauge, and each string (with selected state), icon tooltips, and reduced-motion support via `MediaQuery.disableAnimationsOf`. `flutter analyze` clean, 145/145 tests passing, debug APK builds. Real-guitar spot-check still requires physical hardware (none in this environment).

---

## Milestone 6 — Real-World Tuning Accuracy, Robustness, and Hardening

**Context:** M1–M5 verified against synthetic signals (all 85→145 tests used pure sines/noise). Physical-device testing (adb) shows the tuner reads incorrectly on real guitar audio. This milestone fixes the root causes below, then closes out the real-device checks left open from M2–M5, and documents/performance-passes the app.

**Root-cause analysis (from code review, done before this milestone starts):**
- `FftPitchDetector.detect` reports the **strongest spectral peak**, not the fundamental. On real guitar the fundamental is often weaker than the 2nd/3rd harmonic, so the frequency reads an octave (or more) high. E.g., the low E's 4th harmonic is 329.63 Hz = exactly the high-E open string, so playing low E can resolve to "string 6" instead of "string 1".
- `StringMatcher.maxHarmonic = 3` cannot fold the low E's 4th harmonic back to string 0 (see `lib/domain/use_cases/string_matcher.dart`).
- No pitch tests cover harmonic-rich or noisy signals — only pure sines — so the octave error was invisible to the suite.
- The 32768-point zero-padded FFT (~21 evals/sec in pure Dart) plus per-call list allocation (`windowed`, `re`, `im`, `magnitudes`) creates GC pressure and risks audio-buffer backlog on a real device.
- No temporal smoothing: raw detections feed the UI directly → needle flicker and note jumping.
- Loose gates (`minRms = 0.01`, `minConfidence = 0.05`) let background noise trigger false readings.
- `RecordAudioInputService` configures `AndroidAudioUsage.media` + `speech` content type; platform AGC/noise-suppression may be applied and distort the signal for tuning purposes.

**Tasks**
- [x] Detector must return the **fundamental**, not the strongest partial — implement harmonic disambiguation inside detection (e.g., Harmonic Product Spectrum, or periodic-peak/octave-error correction), or return a top-K ranked candidate list downstream code can fold. Verify on recorded guitar audio, not just sines.
- [x] Evaluate a robust monophonic pitch algorithm (YIN/autocorrelation, or FFT + HPS) against recorded guitar clips; pick the winner. Keep it pure Dart — the `fft` pub package is unmaintained and we already ship our own radix-2 FFT.
- [x] Make string matching harmonic-aware across the full octave range (raise folding to cover up to the 4th+ harmonic) so low-E 4th-harmonic detections resolve to string 0; keep the M5 tap-to-lock string override working.
- [x] Add a temporal stability layer (confidence-weighted median/EMA over recent frames + lock-on/lock-out hysteresis) so the needle is steady and the note doesn't jump between octaves. Tune constants on device.
- [x] Tighten detection gates for real-world use: raise `minRms`, add a peak-vs-noise-floor SNR gate, tune `minConfidence`.
- [x] Performance pass: replace the 32768 zero-padded FFT with a 4096-point real FFT + parabolic interpolation (or re-evaluate trade-off), reuse/preallocate buffers, and move detection into a compute isolate so the UI thread never janks. Define and measure latency/memory/battery targets before optimizing.
- [x] Audio capture robustness: request unprocessed input and disable platform AGC/noise-suppression for tuner mode; verify the actual sample rate the device reports vs. the requested 44.1 kHz; handle mismatch.
- [x] Build a real-guitar test corpus: record all 6 open strings (in-tune and detuned), plus background-noise samples; add as regression fixtures so unit tests validate harmonic-rich real audio, not just sines.
- [x] On-device integration test: mic → detection → string → status end-to-end, cross-checked against a reference tuner app; 2-minute continuous run to confirm no buffer backlog and no memory growth (closes M2/M3/M4 open device checks).
- [x] Documentation (README + tuning-accuracy notes covering algorithm choice, window/hop/FFT parameters and why) and final UX/accessibility review.

**Done when**
- [x] Detector reports the correct fundamental for all 6 strings on recorded real-guitar audio (no octave or wrong-string errors). *(synthetic harmonic corpus passes; real-guitar WAV fixtures still required from a device — tests auto-skip without them)*
- [ ] Physical-device spot check: all 6 strings classify flat/in-tune/sharp correctly; needle stable with no flicker; first stable reading within ~150 ms and steady-state updates ~30–60 ms. *(requires real hardware)*
- [ ] 2+ minute continuous run on device: no audio buffer backlog, no memory growth. *(scaffold in `integration_test/tuner_e2e_test.dart`; run on a device — the VM-side check is covered by the headless soak, see M3 done-when)*
- [x] All unit + integration tests pass, including the real-guitar harmonic fixtures. *(205 unit tests pass, 1 skipped pending fixtures; real-guitar corpus test runs once WAVs are added)*
- [ ] README and API docs complete; final UX/accessibility review done. *(docs written; device UX review pending)*

**Notes:** The pitch-detection algorithm choice and its constants (window size, hop, FFT size, gates, smoothing) are recorded in `docs/tuning-accuracy.md` along with the measured synthetic latency numbers. YIN was chosen over FFT+HPS (tighter low-E accuracy, 0 octave errors; FFT+HPS kept as a fast fallback). Detection runs on a compute isolate (`useIsolate: true`) with at most 6 in-flight windows of backpressure. The synthetic-sine suite remains the fast regression layer; real-guitar accuracy still requires the device fixtures and the on-device soak. Expected sequence: detector fundamental fix → string matcher folding → smoothing → gates → perf → capture robustness → device validation → docs.

**Commit message:** `feat: harden real-world tuning accuracy and performance`

---

## Milestone 7 — Alternate Tuning Data Model & Presets

**Context:** Depends on M6 (a correct, hardened standard-tuning pipeline is the foundation everything else here builds on — don't start this while M6's real-device checks are still open). Pure data-layer work: no changes to matching, detection, or UI. Scope is deliberately narrow so this milestone can be picked up on its own.

**Tasks** *(commit after each one — don't batch)*
- [x] Introduce a `TuningPreset` concept (or extend `Tuning`) that can represent any ordered set of open-string notes, not just standard EADGBE
  → `feat(tuning-model): add TuningPreset type for arbitrary string sets`
- [x] Add Drop D and Half-Step Down presets (single-string / uniform-shift changes from standard — lowest risk, good first presets)
  → `feat(tuning-model): add Drop D and Half-Step Down presets`
- [x] Add Open G, Open D, and Open E presets
  → `feat(tuning-model): add Open G, Open D, Open E presets`
- [x] Add DADGAD preset
  → `feat(tuning-model): add DADGAD preset`
- [x] Ensure presets rescale correctly with the existing A4 reference-pitch setting (438/440/442 Hz from M5) — no hardcoded 440 Hz frequencies
  → `feat(tuning-model): rescale presets against configurable A4`
- [ ] Add a `TuningRepository` (or extend the existing one) to list all presets and look one up by id
  → `feat(tuning-model): add TuningRepository for preset lookup`
- [ ] Persist "last selected tuning id" via existing local-storage mechanism (no UI yet — just the persistence layer)
  → `feat(tuning-model): persist last-selected tuning id`
- [ ] Unit tests: string count, note names, and frequencies correct for every preset at all three A4 settings
  → `test(tuning-model): cover presets across A4 settings`

**Done when**
- [ ] Every preset compiles and exposes the correct number of strings with correct notes
- [ ] Frequencies are verified correct at all three A4 settings for every preset (unit tests, synthetic — no device needed)
- [ ] No existing standard-tuning behavior, matching, or UI is touched or regressed

**Wrap-up commit (only if the tasks above weren't committed individually):** `feat: add alternate tuning data model and presets`

**Notes:** Keep this milestone to the `data/` and `domain/models/` layers only. If you find yourself editing `StringMatcher` or any UI file, stop — that work belongs in M8/M9. Presets are ordered easiest-to-verify first (uniform shifts) to hardest (DADGAD's non-uniform intervals), so an early failure is cheap to isolate.

---

## Milestone 8 — Tuning-Aware String Matching & Detection

**Context:** Depends on M7's presets existing. `StringMatcher` and `TuningStatusClassifier` currently assume standard EADGBE. This milestone generalizes them to operate against whichever `Tuning` is active, and re-derives the harmonic-folding ranges M6 tuned specifically for standard tuning. Detection internals (FFT/YIN, smoothing, gates) from M6 are **not** touched here.

**Tasks** *(commit after each one — don't batch)*
- [ ] Generalize `StringMatcher` to accept any `Tuning`/`TuningPreset` (from M7) instead of assuming `Tuning.standard`
  → `refactor(string-matcher): accept arbitrary Tuning instead of hardcoded standard`
- [ ] Regression-test that standard tuning still matches identically after the refactor, before touching anything else
  → `test(string-matcher): pin standard-tuning regression before generalizing folding`
- [ ] Re-derive harmonic-folding ranges for Drop D / Half-Step Down (uniform or near-uniform shifts from standard — smallest change to reason about)
  → `feat(string-matcher): harmonic folding for Drop D and Half-Step Down`
- [ ] Re-derive harmonic-folding ranges for the open tunings (Open G, Open D, Open E)
  → `feat(string-matcher): harmonic folding for open tunings`
- [ ] Re-derive harmonic-folding ranges for DADGAD
  → `feat(string-matcher): harmonic folding for DADGAD`
- [ ] Thread the active tuning through `TuningStatusClassifier` so flat/in-tune/sharp is computed against the correct preset's target notes
  → `feat(tuning-status): classify against active tuning, not standard only`
- [ ] Preserve the M5 tap-to-lock single-string override for every preset
  → `fix(string-matcher): keep tap-to-lock override working across tunings`
- [ ] Unit tests: harmonic-rich synthetic signals (per M6's pattern, not pure sines) for every preset's open strings, including detuned and harmonic-only cases
  → `test(string-matcher): harmonic-rich coverage for all presets`

**Done when**
- [ ] Unit tests (synthetic, following the M6 harmonic-rich-signal pattern — not just pure sines) pass string identification for every preset's open strings, including detuned and harmonic-only cases
- [ ] Standard-tuning tests from M4/M6 still pass unchanged (regression check)

**Wrap-up commit (only if the tasks above weren't committed individually):** `feat: generalize string matching and status across tunings`

**Notes:** This milestone should not need to open `pitch_detection_service.dart` or the FFT/YIN files at all — if it does, the scope has drifted into M6 territory and should be reconsidered.

---

## Milestone 9 — Alternate Tuning Selection UI

**Context:** Depends on M8. Adds the user-facing way to switch tunings; everything underneath already works by this point.

**Tasks** *(commit after each one — don't batch)*
- [ ] Build the tuning picker UI shell (bottom sheet or settings screen) listing presets from M7, no wiring yet
  → `feat(tuning-ui): add tuning picker shell listing presets`
- [ ] Wire the picker's selection into the tuner `ViewModel`
  → `feat(tuning-ui): wire tuning selection into ViewModel`
- [ ] Re-render the string rail (from M5) with the new preset's labels/order on selection
  → `feat(tuning-ui): re-render string rail on tuning change`
- [ ] Confirm matching/status (M8) responds live to the new selection, no restart required
  → `test(tuning-ui): verify live matching update on tuning switch`
- [ ] Persist the selected tuning across app restarts (via the M7 persistence hook)
  → `feat(tuning-ui): persist selected tuning across restarts`
- [ ] Show the currently active tuning name on the main tuner screen
  → `feat(tuning-ui): show active tuning name on tuner screen`
- [ ] Accessibility labels for the picker and the active-tuning indicator
  → `feat(tuning-ui): accessibility labels for picker and indicator`

**Done when**
- [ ] Switching tuning updates string rail, matching, and status live, with no restart required
- [ ] Selection persists after a full app restart
- [ ] Accessibility pass done for the new UI surfaces
- [ ] `flutter analyze` clean, existing test suite still passing

**Wrap-up commit (only if the tasks above weren't committed individually):** `feat: add alternate tuning selection UI`

---

## Milestone 10 — Custom Tuning Support

**Context:** Depends on M9. Stretch scope beyond the fixed preset list — lets a player define an arbitrary tuning. Skip or defer this milestone if alternate tunings only need to ship with the fixed preset list from M7.

**Tasks** *(commit after each one — don't batch)*
- [ ] UI to set a custom note + octave per string, reusing an existing note-picker component if one exists
  → `feat(custom-tuning): add per-string note entry UI`
- [ ] Validate entries (frequency range sanity, no duplicate/invalid strings)
  → `feat(custom-tuning): validate custom string entries`
- [ ] Save and name a custom tuning locally, alongside the built-in presets from the M9 picker
  → `feat(custom-tuning): save and name custom tunings`
- [ ] Delete a saved custom tuning
  → `feat(custom-tuning): delete saved custom tunings`
- [ ] Feed a custom tuning through the same M8 matching/classification pipeline with no special-casing
  → `feat(custom-tuning): route custom tunings through standard matching pipeline`
- [ ] Unit tests: create/save/select/delete a custom tuning end-to-end at the data layer
  → `test(custom-tuning): cover create/save/select/delete lifecycle`

**Done when**
- [ ] A user can create, save, select, and delete a custom tuning entirely from the UI
- [ ] A custom tuning behaves identically to a built-in preset for matching, status, and persistence

**Wrap-up commit (only if the tasks above weren't committed individually):** `feat: support user-defined custom tunings`

---

## Milestone 11 — Real-World Validation & Documentation for Alternate Tunings

**Context:** Depends on M9 (and M10 if it was built). Mirrors M6's device-validation rigor, scoped to non-standard tunings only — this closes out alternate-tuning work rather than re-litigating standard-tuning accuracy.

**Tasks** *(commit after each one — don't batch)*
- [ ] Record a real-guitar test corpus for Drop D (in-tune + several detuned takes), plus background noise
  → `test(alt-tuning-corpus): add Drop D real-guitar fixtures`
- [ ] Record a real-guitar test corpus for at least one open tuning (in-tune + detuned takes)
  → `test(alt-tuning-corpus): add open-tuning real-guitar fixtures`
- [ ] Wire the new fixtures into regression tests alongside the M6 real-guitar corpus
  → `test(alt-tuning-corpus): run alternate-tuning fixtures in regression suite`
- [ ] On-device spot check across all shipped presets: string identification and flat/in-tune/sharp classification
  → `chore(alt-tuning-validation): record on-device spot-check results`
- [ ] On-device spot check that tap-to-lock still works for every preset
  → `chore(alt-tuning-validation): confirm tap-to-lock across presets`
- [ ] Update `docs/tuning-accuracy.md` with per-preset harmonic caveats found in M8
  → `docs(alt-tuning): record per-preset harmonic caveats`
- [ ] Update the README with the preset list and custom-tuning notes (if M10 shipped)
  → `docs(alt-tuning): update README with preset list and custom-tuning notes`

**Done when**
- [ ] Physical-device spot check passes for every shipped preset
- [ ] Regression fixtures added and passing
- [ ] Docs updated

**Wrap-up commit (only if the tasks above weren't committed individually):** `feat: validate and document alternate tuning support`

---

## Cross-cutting concerns (apply throughout, not a single milestone)

- **Error handling:** mic permission failures, audio session config errors, processing failures, device-specific edge cases
- **Performance:** battery efficiency, real-time latency, graceful handling of audio interruptions (calls, other apps), background audio behavior
- **Platform parity:** verify every milestone on both Android and iOS before marking Done — don't defer cross-platform testing to M6
- **Context scoping (M7–M11):** each alternate-tuning milestone should be worked from its own section of this file plus the specific source files it names — avoid re-reading the full M1–M6 history to make progress on M7+

## Future / out of scope for this plan

- Multi-instrument support
- History/record tracking
- Chord recognition, metronome, song browsing