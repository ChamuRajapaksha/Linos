import 'package:flutter_test/flutter_test.dart';
import 'package:linos/domain/models/tuning.dart';
import 'package:linos/domain/models/tuning_preset.dart';

class _ExpectedPreset {
  const _ExpectedPreset({
    required this.id,
    required this.name,
    required this.labels,
    required this.freqs440,
  });

  final String id;
  final String name;
  final List<String> labels;
  final List<double> freqs440;
}

final _catalog = [
  _ExpectedPreset(
    id: 'standard',
    name: 'Standard',
    labels: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'],
    freqs440: [82.41, 110.00, 146.83, 196.00, 246.94, 329.63],
  ),
  _ExpectedPreset(
    id: 'drop-d',
    name: 'Drop D',
    labels: ['D2', 'A2', 'D3', 'G3', 'B3', 'E4'],
    freqs440: [73.42, 110.00, 146.83, 196.00, 246.94, 329.63],
  ),
  _ExpectedPreset(
    id: 'half-step-down',
    name: 'Half-Step Down',
    labels: ['D#2', 'G#2', 'C#3', 'F#3', 'A#3', 'D#4'],
    freqs440: [77.78, 103.83, 138.59, 185.00, 233.08, 311.13],
  ),
  _ExpectedPreset(
    id: 'open-g',
    name: 'Open G',
    labels: ['D2', 'G2', 'D3', 'G3', 'B3', 'D4'],
    freqs440: [73.42, 98.00, 146.83, 196.00, 246.94, 293.66],
  ),
  _ExpectedPreset(
    id: 'open-d',
    name: 'Open D',
    labels: ['D2', 'A2', 'D3', 'F#3', 'A3', 'D4'],
    freqs440: [73.42, 110.00, 146.83, 185.00, 220.00, 293.66],
  ),
  _ExpectedPreset(
    id: 'open-e',
    name: 'Open E',
    labels: ['E2', 'B2', 'E3', 'G#3', 'B3', 'E4'],
    freqs440: [82.41, 123.47, 164.81, 207.65, 246.94, 329.63],
  ),
  _ExpectedPreset(
    id: 'dadgad',
    name: 'DADGAD',
    labels: ['D2', 'A2', 'D3', 'G3', 'A3', 'D4'],
    freqs440: [73.42, 110.00, 146.83, 196.00, 220.00, 293.66],
  ),
];

void main() {
  group('TuningPreset catalog', () {
    test('has exactly 7 presets with unique ids', () {
      expect(TuningPreset.all.length, 7);
      expect(TuningPreset.all.map((p) => p.id).toSet().length, 7);
    });

    test('byId returns the matching preset for each id', () {
      for (final preset in TuningPreset.all) {
        expect(TuningPreset.byId(preset.id), preset);
      }
    });

    test('byId returns null for unknown id', () {
      expect(TuningPreset.byId('unknown-id'), isNull);
    });
  });

  group('TuningPreset per preset', () {
    for (final expected in _catalog) {
      test(expected.id, () {
        final preset = TuningPreset.byId(expected.id);
        expect(preset, isNotNull);
        expect(preset!.name, expected.name);
        expect(preset.notes.length, 6);
        expect(preset.notes.map((n) => n.label).toList(), expected.labels);

        final tuning = preset.tuningFor(440.0);
        expect(tuning.name, expected.name);
        expect(tuning.notes.length, 6);
        expect(tuning.notes.map((n) => n.label).toList(), expected.labels);
        for (var i = 0; i < 6; i++) {
          expect(tuning.notes[i].frequency, closeTo(expected.freqs440[i], 0.01));
        }
      });
    }
  });

  group('TuningPreset A4 rescaling', () {
    for (final expected in _catalog) {
      for (final a4 in [438.0, 442.0]) {
        test('${expected.id} at A4=$a4', () {
          final preset = TuningPreset.byId(expected.id);
          expect(preset, isNotNull);
          final tuning = preset!.tuningFor(a4);
          expect(tuning.notes.map((n) => n.name).toList(), preset.notes.map((n) => n.name).toList());
          expect(tuning.notes.map((n) => n.octave).toList(), preset.notes.map((n) => n.octave).toList());
          expect(tuning.notes.map((n) => n.label).toList(), expected.labels);
          for (var i = 0; i < 6; i++) {
            expect(
              tuning.notes[i].frequency,
              closeTo(expected.freqs440[i] * a4 / 440.0, 0.01),
            );
          }
        });
      }
    }
  });

  group('TuningPreset.standard.tuningFor(440.0)', () {
    test('equals Tuning.standard', () {
      expect(TuningPreset.standard.tuningFor(440.0), Tuning.standard);
    });
  });
}
