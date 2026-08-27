import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/repositories/last_tuning_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesLastTuningStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = SharedPreferencesLastTuningStore();
  });

  group('SharedPreferencesLastTuningStore.getLastTuningId', () {
    test('returns null when nothing is stored', () async {
      expect(await store.getLastTuningId(), isNull);
    });

    test('returns the stored id after setLastTuningId', () async {
      await store.setLastTuningId('drop-d');
      expect(await store.getLastTuningId(), 'drop-d');
    });
  });

  group('SharedPreferencesLastTuningStore.setLastTuningId', () {
    test('persists the id under the lastTuningId key', () async {
      await store.setLastTuningId('open-g');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lastTuningId'), 'open-g');
    });

    test('overwrites a previously stored id', () async {
      await store.setLastTuningId('standard');
      await store.setLastTuningId('dadgad');
      expect(await store.getLastTuningId(), 'dadgad');
    });
  });
}
