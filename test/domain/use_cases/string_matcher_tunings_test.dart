import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/repositories/pitch_detector.dart';
import 'package:linos/data/repositories/yin_pitch_detector.dart';
import 'package:linos/domain/models/tuning_preset.dart';
import 'package:linos/domain/models/tuning_status.dart';
import 'package:linos/domain/use_cases/string_matcher.dart';

import '../../helpers/guitar_signal.dart';

/// Covers M8: string identification and harmonic folding across every preset,
/// following the M6 harmonic-rich-signal pattern rather than pure sines.
///
/// Presets are ordered by how their folding behaves relative to standard:
///  - Uniform / near-uniform shifts (Drop D, Half-Step Down) preserve every
///    harmonic relationship from standard tuning, so their folding ranges are
///    identical.
///  - The octave-stacked open tunings (Open G/D/E) and DADGAD place a lower
///    string's 2nd harmonic exactly on a higher string's fundamental. Per the
///    M5/M6 rule ("a genuine fundamental wins over a lower string's
///    harmonic"), those readings resolve to the string whose fundamental it
///    is; the same choice the standard tuning makes at low-E's 4th harmonic.
void main() {
  final detector = YinPitchDetector(config: const PitchDetectorConfig());

  /// Full pipeline: pluck -> YIN fundamental -> StringMatcher.
  StringMatch? matchPluck(
    StringMatcher matcher,
    double f0, {
    double detuneCents = 0,
    int boostHarmonic = 0,
  }) {
    final samples = generatePluckedString(
      frequency: f0,
      numSamples: 4096,
      sampleRate: 44100,
      detuneCents: detuneCents,
      boostHarmonic: boostHarmonic,
      boostAmplitude: 1.5,
    );
    final pitch = detector.detect(samples);
    if (pitch == null) {
      return null;
    }
    return matcher.identify(pitch.frequency.value);
  }

  group('standard-tuning regression (pinned before generalizing folding)', () {
    final matcher = StringMatcher();

    test('all six open strings identify at their fundamental', () {
      final expected = [0, 1, 2, 3, 4, 5];
      for (var i = 0; i < standardTuningFrequencies.length; i++) {
        final f0 = standardTuningFrequencies[i];
        final m = matcher.identify(f0);
        expect(m, isNotNull, reason: 'string $i ($f0 Hz)');
        expect(m!.stringIndex, expected[i]);
        expect(m.harmonic, 1);
        expect(m.centsOffset.abs(), lessThan(0.5));
      }
    });

    test('harmonic folding still folds a non-colliding low-E 2nd partial', () {
      // 164.82 is not near any standard fundamental, so it folds to low E.
      expect(matcher.identify(82.41 * 2)!.stringIndex, 0);
      expect(matcher.identify(82.41 * 2)!.harmonic, 2);
    });

    test('low-E 3rd/4th partials prefer the colliding fundamental', () {
      // E2's 3rd partial (247.23) ~ B3 fundamental; 4th partial (329.64) ~ E4.
      expect(matcher.identify(82.41 * 3)!.stringIndex, 4);
      expect(matcher.identify(82.41 * 4)!.stringIndex, 5);
    });

    test('a genuine high-E still wins over low-E 4th harmonic', () {
      final m = matcher.identify(329.63);
      expect(m!.stringIndex, 5);
      expect(m.harmonic, 1);
    });
  });

  group('uniform-shift presets share standard folding', () {
    for (final preset in [TuningPreset.dropD, TuningPreset.halfStepDown]) {
      final tuning = preset.tuningFor(440);
      final matcher = StringMatcher(tuning: tuning);

      test('${preset.name}: open strings identify at fundamentals', () {
        for (var i = 0; i < tuning.notes.length; i++) {
          final m = matcher.identify(tuning.notes[i].frequency);
          expect(m, isNotNull, reason: '${preset.name} string $i');
          expect(m!.stringIndex, i);
          expect(m.harmonic, 1);
          expect(m.centsOffset.abs(), lessThan(0.5));
          expect(m.status, TuningStatus.inTune);
        }
      });

      test('${preset.name}: detuned low string stays on its string', () {
        final low = tuning.notes[0];
        final detuned = low.frequency * 0.977; // ~ -40 cents
        final m = matcher.identify(detuned);
        expect(m!.stringIndex, 0);
        expect(m.status, TuningStatus.flat);
      });

      test('${preset.name}: tap-to-lock identifies the locked string', () {
        for (var i = 0; i < tuning.notes.length; i++) {
          final m = matcher.identifyString(i, tuning.notes[i].frequency);
          expect(m.stringIndex, i, reason: '${preset.name} lock string $i');
          expect(m.harmonic, 1);
          expect(m.status, TuningStatus.inTune);
        }
      });
    }

    test('Drop D: D2 2nd partial prefers the D3 fundamental', () {
      final tuning = TuningPreset.dropD.tuningFor(440);
      final matcher = StringMatcher(tuning: tuning);
      // D2's 2nd partial (146.83) is exactly D3's fundamental (string 2).
      final m = matcher.identify(tuning.notes[0].frequency * 2);
      expect(m!.stringIndex, 2);
      expect(m.harmonic, 1);
    });

    test('Half-Step Down: genuine top-string fundamental beats low 4th', () {
      final tuning = TuningPreset.halfStepDown.tuningFor(440);
      final matcher = StringMatcher(tuning: tuning);
      final top = tuning.notes[5].frequency; // D#4
      final m = matcher.identify(top);
      expect(m!.stringIndex, 5);
      expect(m.harmonic, 1);
    });
  });

  group('open tunings', () {
    for (final preset in [TuningPreset.openG, TuningPreset.openD, TuningPreset.openE]) {
      final tuning = preset.tuningFor(440);
      final matcher = StringMatcher(tuning: tuning);

      test('${preset.name}: open strings identify at fundamentals', () {
        for (var i = 0; i < tuning.notes.length; i++) {
          final m = matcher.identify(tuning.notes[i].frequency);
          expect(m, isNotNull, reason: '${preset.name} string $i');
          expect(m!.stringIndex, i);
          expect(m.harmonic, 1);
          expect(m.centsOffset.abs(), lessThan(0.5));
        }
      });

      test('${preset.name}: detuned string stays on its target', () {
        final detuned = tuning.notes[0].frequency * 0.977;
        final m = matcher.identify(detuned);
        expect(m!.stringIndex, 0);
        expect(m.status, TuningStatus.flat);
      });

      test('${preset.name}: tap-to-lock works for every string', () {
        for (var i = 0; i < tuning.notes.length; i++) {
          final m = matcher.identifyString(i, tuning.notes[i].frequency);
          expect(m.stringIndex, i, reason: '${preset.name} lock string $i');
        }
      });

      test('${preset.name}: a lower string\'s 2nd harmonic goes to the octave string', () {
        // e.g. Open G string D3 (idx 2) 2nd harmonic == D4 (idx 5) fundamental.
        final lowString = tuning.notes[0];
        final harmonic2 = lowString.frequency * 2;
        if (tuning.notes.indexWhere(
                (n) => (n.frequency - harmonic2).abs() < harmonic2 * 0.01) !=
            -1) {
          final m = matcher.identify(harmonic2);
          final octaveIndex = tuning.notes
              .indexWhere((n) => (n.frequency - harmonic2).abs() < harmonic2 * 0.01);
          expect(m!.stringIndex, octaveIndex);
          expect(m.harmonic, 1);
        }
      });
    }
  });

  group('DADGAD', () {
    final tuning = TuningPreset.dadgad.tuningFor(440);
    final matcher = StringMatcher(tuning: tuning);

    test('open strings identify at fundamentals', () {
      for (var i = 0; i < tuning.notes.length; i++) {
        final m = matcher.identify(tuning.notes[i].frequency);
        expect(m, isNotNull, reason: 'DADGAD string $i');
        expect(m!.stringIndex, i);
        expect(m.harmonic, 1);
      }
    });

    test('detuned strings stay on target', () {
      final m = matcher.identify(tuning.notes[1].frequency * 0.977);
      expect(m!.stringIndex, 1);
      expect(m.status, TuningStatus.flat);
    });

    test('tap-to-lock works for every string', () {
      for (var i = 0; i < tuning.notes.length; i++) {
        final m = matcher.identifyString(i, tuning.notes[i].frequency);
        expect(m.stringIndex, i);
        expect(m.status, TuningStatus.inTune);
      }
    });
  });

  group('harmonic-rich pipeline (M6 pattern), all presets', () {
    for (final preset in TuningPreset.all) {
      final tuning = preset.tuningFor(440);
      final matcher = StringMatcher(tuning: tuning);

      test('${preset.name}: each open string pluck identifies correctly', () {
        for (var i = 0; i < tuning.notes.length; i++) {
          final m = matchPluck(matcher, tuning.notes[i].frequency);
          expect(m, isNotNull, reason: '${preset.name} string $i');
          expect(
            m!.stringIndex,
            i,
            reason: '${preset.name} string $i (harmonic-rich pluck)',
          );
          expect(m.status, TuningStatus.inTune);
        }
      });

      test('${preset.name}: detuned pluck stays on its string', () {
        for (var i = 0; i < tuning.notes.length; i++) {
          final low = tuning.notes[0].frequency;
          final m = matchPluck(matcher, low, detuneCents: -40);
          expect(m, isNotNull);
          expect(m!.stringIndex, 0, reason: '${preset.name} detuned low string');
          expect(m.status, TuningStatus.flat);
        }
      });

      test('${preset.name}: boosted-harmonic pluck (weak fundamental) resolves', () {
        final m = matchPluck(matcher, tuning.notes[0].frequency, boostHarmonic: 2);
        expect(m, isNotNull, reason: '${preset.name} boosted-harmonic pluck');
      });
    }
  });
}
