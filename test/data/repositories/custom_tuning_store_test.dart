import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/repositories/custom_tuning_store.dart';
import 'package:linos/domain/models/tuning_preset.dart';
import 'package:shared_preferences/shared_preferences.dart';

TuningPreset makePreset(String id, String name, List<String> notes) {
  return TuningPreset(
    id: id,
    name: name,
    notes: [
      for (final spec in notes)
        TuningPreset.noteFor(
          spec.substring(0, spec.length - 1),
          int.parse(spec.substring(spec.length - 1)),
        ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesCustomTuningStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = SharedPreferencesCustomTuningStore();
  });

  group('SharedPreferencesCustomTuningStore.loadCustomTunings', () {
    test('returns empty when nothing is stored', () async {
      expect(await store.loadCustomTunings(), isEmpty);
    });

    test('returns tunings persisted via saveAll, sorted by name', () async {
      final dadgad = makePreset('custom-a', 'Dadgad', ['D2', 'A2', 'D3', 'G3', 'A3', 'D4']);
      final dropC = makePreset('custom-b', 'Drop C', ['C2', 'G2', 'C3', 'F3', 'A3', 'D4']);
      await store.saveAll([dadgad, dropC]);

      final loaded = await store.loadCustomTunings();
      expect(loaded.length, 2);
      expect(loaded.first.name, 'Dadgad');
      expect(loaded.last.name, 'Drop C');
      expect(loaded.first.notes[0].frequency, closeTo(73.42, 0.01));
    });
  });

  group('SharedPreferencesCustomTuningStore.saveAll', () {
    test('persists names and notes under the customTunings key', () async {
      final preset = makePreset('custom-1', 'Nashville', ['E3', 'A3', 'D4', 'G4', 'B3', 'E4']);
      await store.saveAll([preset]);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('customTunings'), isNotNull);
    });

    test('overwrites the entire set', () async {
      await store.saveAll([makePreset('custom-1', 'A', ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'])]);
      await store.saveAll([makePreset('custom-2', 'B', ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'])]);

      final loaded = await store.loadCustomTunings();
      expect(loaded.length, 1);
      expect(loaded.single.name, 'B');
    });
  });
}
