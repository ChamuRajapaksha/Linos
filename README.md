# Linos

A real-time guitar tuner built with Flutter. Listen to your instrument through the microphone and get live pitch feedback to tune each string.

## Status

Core architecture, audio input, permissions, pitch detection, tuning logic, and the full tuner UI are in place. Remaining work is milestone 6: testing, documentation, and performance.

| Milestone | Status |
|-----------|--------|
| 1. Core architecture and foundation | Done |
| 2. Audio input and permissions | Done |
| 3. Basic pitch detection engine | Done |
| 4. Tuning logic and feedback system | Done |
| 5. Complete tuner UI with polish | Done |
| 6. Testing, documentation, performance | Not Started |

## Features

- **MVVM + repository architecture** with clean separation of data, domain, and UI layers
- **Microphone input** via the `record` package (PCM16 mono 44.1 kHz stream) with runtime permission handling on Android and iOS
- **Audio session configuration** via `audio_session`
- **Dependency injection** with `get_it`
- **FFT-based pitch detection engine** — self-contained radix-2 FFT with Hann windowing, zero-padding, and parabolic interpolation (~1 Hz accuracy on synthetic tones)
- **Note mapping** — frequency to nearest note with cent offset
- **Continuous processing loop** — sliding-window pitch detection over the live audio stream
- **Tuning logic** — standard tuning reference, per-string identification with harmonic folding, and flat/in-tune/sharp classification (±5 cents band)
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
- Milestone 2 device verification is pending — microphone behavior differs between simulators and physical devices, so real hardware testing is planned before pitch detection work starts.

## Roadmap

Upcoming work, per the build plan in `.agents/plans/project-planner.md`:

- Unit and integration tests, performance optimization
- Physical-device verification (real-guitar tuning flow, memory over long sessions)

## Out of Scope

Alternate tunings, multi-instrument support, tuning history, chord recognition, and metronome features are future ideas not yet planned.