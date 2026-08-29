import 'package:flutter_test/flutter_test.dart';
import 'package:linos/domain/models/note.dart';
import 'package:linos/domain/models/tuning_preset.dart';
import 'package:linos/domain/use_cases/custom_tuning_validator.dart';

List<Note> notes(List<String> specs) {
  return [
    for (final spec in specs)
      TuningPreset.noteFor(
        spec.substring(0, spec.length - 1),
        int.parse(spec.substring(spec.length - 1)),
      ),
  ];
}

void main() {
  const List<String> valid = ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'];

  group('CustomTuningValidator.validate', () {
    test('accepts a six-string tuning with a name', () {
      final result =
          CustomTuningValidator.validate(name: 'My Tuning', notes: notes(valid));
      expect(result.isValid, isTrue);
      expect(result.nameError, isNull);
      expect(result.stringErrors, isEmpty);
    });

    test('rejects an empty name', () {
      final result =
          CustomTuningValidator.validate(name: '   ', notes: notes(valid));
      expect(result.isValid, isFalse);
      expect(result.nameError, isNotNull);
    });

    test('rejects an overly long name', () {
      final result = CustomTuningValidator.validate(
        name: 'x' * 25,
        notes: notes(valid),
      );
      expect(result.isValid, isFalse);
      expect(result.nameError, isNotNull);
    });

    test('rejects a tuning that is not six strings', () {
      final result = CustomTuningValidator.validate(
        name: 'Five',
        notes: notes(['E2', 'A2', 'D3', 'G3', 'B3']),
      );
      expect(result.isValid, isFalse);
      expect(result.stringErrors, isNotEmpty);
    });

    test('rejects an invalid note name', () {
      final result = CustomTuningValidator.validate(
        name: 'Bad',
        notes: [
          ...notes(['E2', 'A2', 'D3', 'G3', 'B3']),
          TuningPreset.noteFor('H', 4),
        ],
      );
      expect(result.isValid, isFalse);
      expect(result.stringErrors[5], isNotNull);
    });

    test('rejects an out-of-range octave', () {
      final result = CustomTuningValidator.validate(
        name: 'Low',
        notes: [
          TuningPreset.noteFor('E', -1),
          ...notes(['A2', 'D3', 'G3', 'B3', 'E4']),
        ],
      );
      expect(result.isValid, isFalse);
      expect(result.stringErrors[0], isNotNull);
    });
  });
}
