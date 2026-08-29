import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/repositories/tuning_repository.dart';
import 'package:linos/domain/models/tuning_preset.dart';

void main() {
  final repository = TuningRepository();

  group('TuningRepository.listPresets', () {
    test('returns 7 presets with the same ids as TuningPreset.all', () {
      final presets = repository.listPresets();
      expect(presets.length, 7);
      expect(
        presets.map((p) => p.id).toList(),
        TuningPreset.all.map((p) => p.id).toList(),
      );
    });
  });

  group('TuningRepository.getPreset', () {
    test('returns the standard preset for standard', () {
      expect(repository.getPreset('standard'), TuningPreset.standard);
    });

    test('returns null for unknown id', () {
      expect(repository.getPreset('nope'), isNull);
    });
  });

  group('TuningRepository.tuningFor', () {
    test('standard at default A4 has standard frequencies', () {
      final tuning = repository.tuningFor('standard');
      final expected = [82.41, 110.0, 146.83, 196.0, 246.94, 329.63];
      for (var i = 0; i < 6; i++) {
        expect(tuning.notes[i].frequency, closeTo(expected[i], 0.01));
      }
    });

    test('drop-d at A4=442 scales frequencies by the ratio', () {
      final tuning = repository.tuningFor('drop-d', a4Reference: 442.0);
      expect(tuning.notes[0].frequency, closeTo(73.42 * 442.0 / 440.0, 0.01));
      expect(tuning.notes[5].frequency, closeTo(329.63 * 442.0 / 440.0, 0.01));
    });

    test('throws ArgumentError for unknown id', () {
      expect(() => repository.tuningFor('unknown'), throwsArgumentError);
    });
  });
}
