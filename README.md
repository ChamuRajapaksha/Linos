# Linos

A real-time guitar tuner built with Flutter. Listen to your instrument through the microphone and get live pitch feedback to tune each string.

## Status

Early development. Core architecture, audio input, and microphone permission handling are in place. Pitch detection (milestone 3) is the next milestone.

| Milestone | Status |
|-----------|--------|
| 1. Core architecture and foundation | Done |
| 2. Audio input and permissions | In Progress |
| 3. Basic pitch detection engine | Not Started |
| 4. Tuning logic and feedback system | Not Started |
| 5. Complete tuner UI with polish | Not Started |
| 6. Testing, documentation, performance | Not Started |

## Features

- **MVVM + repository architecture** with clean separation of data, domain, and UI layers
- **Microphone input** via the `record` package (PCM16 mono 44.1 kHz stream) with runtime permission handling on Android and iOS
- **Audio session configuration** via `audio_session`
- **Dependency injection** with `get_it`
- **Core domain models** ready for tuning logic: `Note`, `Tuning`, `Frequency`, `TuningStatus`, `StringState`

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

- FFT-based pitch detection with a real-time processing loop
- Standard tuning (E-A-D-G-B-E) reference table and flat/in-tune/sharp classification
- Per-string detection that works even on badly out-of-tune strings
- Gauge/needle tuning UI with animations and accessibility pass
- Unit and integration tests, performance optimization

## Out of Scope

Alternate tunings, multi-instrument support, tuning history, chord recognition, and metronome features are future ideas not yet planned.