# Tuning Accuracy & Performance Notes

This document records how Linos turns microphone audio into a stable, accurate
pitch reading, why the algorithm and parameters were chosen, and how to verify
accuracy on real devices. It complements the test evidence in
`test/data/repositories/pitch_algorithm_comparison_test.dart`.

## Pipeline

```
mic (PCM16 mono 44.1 kHz, unprocessed source)
  -> RecordAudioInputService   (fallback chain: unprocessed -> voiceRecognition -> mic)
  -> PitchDetectionService     (sliding window: 4096 samples, 2048 hop)
  -> PitchDetector             (YIN by default, HPS-FFT optional)   [compute isolate]
  -> PitchSmoother             (lock-on/lock-off hysteresis + EMA)
  -> NoteMatcher / StringMatcher (harmonic folding, cents offset)
  -> TunerViewModel            (note readout, string rail, gauge)
```

## Algorithm choice: YIN vs FFT + HPS

Both candidates were implemented in pure Dart and benchmarked against a
synthetic "plucked guitar string" corpus (all six open strings, harmonics with
a weak fundamental, in-tune and detuned) and a real-guitar WAV corpus when
fixtures are present (`test/fixtures/guitar/*.wav`, see the README there).

| Metric              | YIN                     | FFT + HPS (order 3)     |
|---------------------|-------------------------|-------------------------|
| Mean cents error    | 2.2–2.6 ¢/string        | 0.6–2.9 ¢/string        |
| Max cents error     | 2.66 ¢                  | 3.46 ¢                  |
| Octave errors       | 0 / 6 strings           | 0 / 6 strings           |
| Best per-frame cost | ~3 ms                   | ~0.5 ms                 |
| Frame budget (46 ms) | 6.7%                   | 1.1%                    |

Both algorithms fit the real-time frame budget (hop 2048 / 44 100 Hz ≈ 46 ms)
by a wide margin. YIN was chosen as the default because it is a
periodicity-based method that is structurally robust to a weak fundamental
with strong harmonics, and its error is tighter at the low-E octave errors
that historically plagued the FFT peak-pick. The FFT + HPS detector remains
available as a fast fallback (`PitchDetectorConfig.useHps`, or
`DetectorKind.fft` on the isolate) and is cross-checked by the comparison test
so both stay honest.

## Detection parameters (`PitchDetectorConfig`)

| Parameter       | Value | Why |
|-----------------|-------|-----|
| `windowSize`    | 4096  | ~93 ms of audio; long enough for low-E period (~22 ms), short enough for ~15 Hz frequency resolution before interpolation |
| `fftSize`       | 4096  | The old 32768 zero-padded FFT was ~8× more expensive; parabolic interpolation keeps pure-sine accuracy ≤ 0.18 Hz at 4096 |
| `sampleRate`    | 44100 | Requested rate; the device may resample, see "Sample-rate handling" |
| `minFrequency`  | 70 Hz | Below low-E (82.41 Hz); guards octave-down drift |
| `maxFrequency`  | 1400 Hz | Above high-E ×2; keeps YIN lag search cheap and focused |
| `minConfidence` | 0.20  | Rejects unreliable frames before smoothing |
| `minRms`        | 0.02  | Rejects silence and quiet background noise |
| `minSnrDb`      | 6.0 dB | Peak-vs-noise-floor gate; rejects tonal noise like HVAC hum |
| `useHps`        | false | YIN is the default; HPS mode for the FFT path |
| YIN `threshold` | 0.10  | Absolute CMNDF dip threshold; small = tighter, requires local-minimum + fallback to global min |

## Temporal stability (`PitchSmoother`)

Raw per-frame readings flicker and jump octaves, so the service only emits a
value once a candidate has been consistent:

| Parameter             | Value | Behavior |
|-----------------------|-------|----------|
| `lockOnFrames`        | 3     | Three consistent candidate frames acquire a note (first stable reading ~140–190 ms) |
| `lockOffFrames`       | 2     | Two consistent far-off readings (≥ `switchThresholdCents`) switch the note |
| `maxLockCents`        | 40    | Within 40 ¢ of the current value = same note, EMA-updated |
| `switchThresholdCents`| 60    | Outliers in the 40–60 ¢ guard band hold the current value |
| `emaAlpha`            | 0.35  | EMA smoothing factor, scaled by confidence (×0.25 below 0.1 confidence) |
| `maxHeldFrames`       | 15    | Frames of silence before the lock is released |

With lock-on = 3 and a window of 4096 samples at hop 2048 (~21 frames/s),
a stable reading appears in ~140–190 ms and steady-state updates land in the
~30–60 ms range, matching the M6 device targets.

## Gates

`minRms = 0.02`, `minConfidence = 0.20`, `minSnrDb = 6.0` — tightened from the
original `0.01`/`0.05` defaults so background noise and quiet room tones do
not produce false readings, while a strummed string passes comfortably.

## Capture robustness

- `buildTunerRecordConfig`: PCM16 mono 44.1 kHz, `autoGain: false`,
  `echoCancel: false`, `noiseSuppress: false`, `manageBluetooth: false` so the
  platform cannot apply AGC/noise-suppression that distorts tuning.
- `RecordAudioInputService` requests `AndroidAudioSource.unprocessed` first,
  falls back to `voiceRecognition`, then `mic`, and reports which source won
  (`activeSource`). The Android audio session uses `contentType: music`.

## Sample-rate handling

The recorder is asked for 44.1 kHz but some devices resample. The detectors
use `config.sampleRate` (44 100) to convert lag to frequency; if a device
reports a different rate (check `activeSource`/platform logs during the
on-device test), update `PitchDetectorConfig.sampleRate` to the real value and
re-run the comparison corpus.

## Performance

- Detection runs on a compute isolate (`useIsolate: true` in `di/locator.dart`),
  with the UI thread only buffering samples and applying the smoother.
- Backpressure: at most `maxPendingWindows = 6` windows in flight; excess
  windows are dropped so the buffer never grows under load.
- The YIN cost function is O(τ·N) over a bounded lag range with preallocated
  buffers (no per-call allocation in the hot path); FFT buffers are likewise
  preallocated and reused.
- Targets: 46 ms frame budget (hop 2048 / 44.1 kHz) — both detectors use a
  small fraction of it on current hardware.

## Device verification checklist

Run the on-device integration test (`integration_test/tuner_e2e_test.dart`,
2-minute soak: no errors, bounded buffer, ≤ 32 MB RSS growth) and cross-check
each open string against a reference tuner app:

1. All six strings classify flat/in-tune/sharp correctly (no octave or
   wrong-string errors).
2. First stable reading within ~150 ms; steady-state updates every ~30–60 ms.
3. Needle steady, no flicker or note jumping on a sustained note.
4. Add real-guitar WAV fixtures to `test/fixtures/guitar/` (see
   `test/fixtures/guitar/README.md`) so the unit suite covers harmonic-rich
   audio, not just sines.
5. Confirm the reported sample rate matches the configured 44.1 kHz.
