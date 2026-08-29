import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/repositories/custom_tuning_store.dart';
import 'package:linos/data/repositories/tuning_repository.dart';
import 'package:linos/domain/models/note.dart';
import 'package:linos/domain/models/tuning_preset.dart';
import 'package:linos/domain/use_cases/string_matcher.dart';
import 'package:linos/domain/use_cases/tuning_status_classifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  TuningRepository buildRepository() {
    return TuningRepository(customTuningStore: SharedPreferencesCustomTuningStore());
  }

  group('TuningRepository custom tuning lifecycle', () {
    test('create save and list a custom tuning', () async {
      final repo = buildRepository();
      await repo.refreshCustomTunings();
      expect(repo.listPresets().length, 7);

      final saved = await repo.saveCustomTuning(
        name: 'Drop C',
        notes: notes(['C2', 'G2', 'C3', 'F3', 'A3', 'D4']),
      );

      expect(saved.id, startsWith('custom-'));
      expect(repo.listPresets().length, 8);
      expect(repo.getPreset(saved.id), saved);
    });

    test('custom tuning is retrievable through tuningFor', () async {
      final repo = buildRepository();
      await repo.refreshCustomTunings();
      final saved = await repo.saveCustomTuning(
        name: 'Nashville',
        notes: notes(['E3', 'A3', 'D4', 'G4', 'B3', 'E4']),
      );

      final tuning = repo.tuningFor(saved.id);
      expect(tuning.notes.length, 6);
      expect(tuning.notes[0].label, 'E3');
      expect(tuning.notes[0].frequency, closeTo(164.81, 0.01));
    });

    test('routes a custom tuning through the matching pipeline', () async {
      final repo = buildRepository();
      final preset = await repo.saveCustomTuning(
        name: 'Drop C',
        notes: notes(['C2', 'G2', 'C3', 'F3', 'A3', 'D4']),
      );
      final matcher = StringMatcher(
        tuning: preset.tuningFor(440.0),
        classifier: const TuningStatusClassifier(),
      );

      final match = matcher.identify(65.41);
      expect(match, isNotNull);
      expect(match!.stringIndex, 0);
      expect(match.targetNote.label, 'C2');
    });

    test('custom tuning persists across a repository restart', () async {
      final repo1 = buildRepository();
      await repo1.refreshCustomTunings();
      final saved = await repo1.saveCustomTuning(
        name: 'Open C',
        notes: notes(['C2', 'G2', 'C3', 'G3', 'C4', 'E4']),
      );

      final fresh = buildRepository();
      await fresh.refreshCustomTunings();
      expect(fresh.listPresets().length, 8);
      expect(fresh.getPreset(saved.id)?.name, 'Open C');
    });

    test('delete removes a custom tuning from the list and persistence', () async {
      final repo = buildRepository();
      await repo.refreshCustomTunings();
      final saved = await repo.saveCustomTuning(
        name: 'Delete Me',
        notes: notes(['E2', 'A2', 'D3', 'G3', 'B3', 'E4']),
      );
      expect(repo.getPreset(saved.id), isNotNull);

      await repo.deleteCustomTuning(saved.id);

      expect(repo.getPreset(saved.id), isNull);
      expect(repo.listPresets().length, 7);

      final fresh = buildRepository();
      await fresh.refreshCustomTunings();
      expect(fresh.listPresets().length, 7);
    });

    test('isCustomId distinguishes custom from built-in ids', () {
      final repo = buildRepository();
      expect(repo.isCustomId('custom-123-4'), isTrue);
      expect(repo.isCustomId('standard'), isFalse);
      expect(repo.isCustomId('drop-d'), isFalse);
    });
  });
}
