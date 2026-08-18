# Real guitar corpus fixtures

The in-repo test corpus is synthetic (see `test/helpers/guitar_signal.dart`,
`generatePluckedString`). To validate against real audio, record each open
string and drop the WAV files here.

`test/data/repositories/real_guitar_corpus_test.dart` picks them up
automatically and **skips itself when this directory contains no `.wav`
files**, so the suite stays green until you add recordings.

## Naming convention

`<stringNumber>-<detuneCents>.wav`

- `stringNumber` 1..6 (string 1 = low E, 82.41 Hz; string 6 = high E, 329.63 Hz)
- `detuneCents` in cents relative to the string's open pitch in standard tuning
  (0 = in tune, e.g. `-50` = 50 cents flat, `+50` = 50 cents sharp)

Examples:

- `1-0.wav` — low E in tune (82.41 Hz)
- `1-50.wav` — low E tuned 50 cents sharp
- `6--50.wav` — high E tuned 50 cents flat

## Recording procedure

1. Tune the guitar to A4 = 440 Hz first.
2. Use a close microphone (built-in phone mic at ~20-30 cm works).
3. Record in **PCM 16-bit, mono, 44.1 kHz** (most recorder apps export this;
   the WAV loader also handles stereo and averages to mono).
4. Pluck each open string once, single note, and let it ring ~2 seconds.
5. Trim each take to one note (a clean ~2 s clip), export each as a separate WAV,
   and name it per the convention above.

## Running

```sh
flutter test test/data/repositories/real_guitar_corpus_test.dart
```

When fixtures exist, YIN runs a 4096-sample window (starting ~0.5 s into the
clip, past the pluck transient) and asserts the detected pitch is within
10 cents of the expected fundamental.
