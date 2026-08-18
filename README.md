# Linos

A real-time guitar tuner built with Flutter. Listen to your instrument through the microphone and get live pitch feedback to tune each string.

## Status

Core architecture, audio input, permissions, pitch detection, tuning logic, the full tuner UI, and real-world accuracy hardening are in place. The unit suite (205 tests + 1 skipped) covers synthetic signals, a harmonic-rich guitar corpus, the detection service, audio-capture robustness, and smoothing. Remaining work is on-device verification with a real guitar and a reference tuner (see [docs/tuning-accuracy.md](docs/tuning-accuracy.md)).

| Milestone | Status |
|-----------|--------|
| 1. Core architecture and foundation | Done |
| 2. Audio input and permissions | Done |
| 3. Basic pitch detection engine | Done |
| 4. Tuning logic and feedback system | Done |
| 5. Complete tuner UI with polish | Done |
| 6. Testing, documentation, performance | In Progress |

## Features

- **MVVM + repository architecture** with clean separation of data, domain, and UI layers
- **Microphone input** via the `record` package (PCM16 mono 44.1 kHz stream) with runtime permission handling on Android and iOS
- **Audio session configuration** via `audio_session`
- **Dependency injection** with `get_it`
- **FFT-based pitch detection engine** — self-contained radix-2 FFT with Hann windowing, zero-padding, and parabolic interpolation (~1 Hz accuracy on synthetic tones)
- **YIN pitch detection** — default detector; periodicity-based and robust to a weak fundamental with strong harmonics (max 2.66 ¢ on the synthetic guitar corpus); HPS-FFT available as a fast fallback
- **Compute-isolate detection** — the detector runs off the UI thread with bounded in-flight backpressure, so the UI never janks
- **Temporal smoothing** — lock-on/lock-off hysteresis plus confidence-scaled EMA keeps the needle steady and stops octave jumping
- **Tightened gates** — minimum RMS, confidence, and a peak-vs-noise-floor SNR gate reject silence and background noise
- **Raw capture** — requests unprocessed mic input with AGC/echo/noise suppression off, with a fallback chain across Android audio sources
- **Note mapping** — frequency to nearest note with cent offset
- **Continuous processing loop** — sliding-window pitch detection over the live audio stream
- **Tuning logic** — standard tuning reference, per-string identification with harmonic folding (up to the 4th harmonic), and flat/in-tune/sharp classification (±5 cents band)
- **Production tuner UI** — signature six-string rail (tap a string to focus it, tap again for auto-detection), animated V-gauge needle, hero note readout, and a reference-pitch setting (A4 = 438/440/442 Hz)
- **Instrument-themed design system** — warm walnut/ebony surfaces, brass accents, directional status colors (slate = flat, emerald = in tune, ember = sharp), reduced-motion support
- **Accessibility** — screen-reader labels for the note readout, gauge, and each string; visible focus; contrast-checked palette
- **Core domain models**: `Note`, `Tuning`, `Frequency`, `TuningStatus`, `StringState`

## Architecture

```
lib/
├── data/
│   ├── models/              # Domain models (Note, Tuning, Frequency)
│   ├── repositories/        # Audio processing and pitch detection logic
│   └── services/            # Audio input handling, platform plugins
├── domain/
│   ├── models/              # Clean data models
│   └── use_cases/           # Business logic for tuning operations
├── di/                      # Dependency injection container
└── ui/
    ├── core/                # Shared UI components, themes, typography
    └── features/
        └── tuner/
            ├── view_models/
            └── views/
```

## Getting Started

### Prerequisites

- Flutter SDK `^3.11.0`
- Android Studio / Xcode with a device or emulator

### Run

```sh
flutter pub get
flutter run
```

### Build

```sh
flutter build apk --debug    # Android
flutter build ios            # iOS (requires macOS)
```

## Platform Notes

- `permission_handler` is pinned to `12.0.1` — the 13.x line pulls `permission_handler_android` 14.x which requires AGP 9/Kotlin 2.3 and is incompatible with Flutter 3.41.
- Real-device verification (microphone behavior, unprocessed audio source fallback, and tuning accuracy on physical hardware) is tracked in milestone 6 — run `integration_test/tuner_e2e_test.dart` and add real-guitar fixtures per `docs/tuning-accuracy.md`.

## Roadmap

Remaining work, per the build plan in `.agents/plans/project-planner.md`:

- On-device verification: real-guitar tuning flow cross-checked against a reference tuner, 2-minute soak run, and real-guitar WAV fixtures for the unit corpus (see `docs/tuning-accuracy.md`)
- Final UX/accessibility review on physical hardware

## Out of Scope

Alternate tunings, multi-instrument support, tuning history, chord recognition, and metronome features are future ideas not yet planned.