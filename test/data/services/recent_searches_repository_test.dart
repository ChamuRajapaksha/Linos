import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/services/recent_searches_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late RecentSearchesRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = RecentSearchesRepository();
    await repository.load();
  });

  group('RecentSearchesRepository', () {
    test('starts empty', () {
      expect(repository.recent, isEmpty);
    });

    test('add trims, ignores empty entries, and persists', () async {
      await repository.add('  ');
      expect(repository.recent, isEmpty);

      await repository.add('wonderwall');
      expect(repository.recent, ['wonderwall']);
    });

    test('add dedupes and moves existing entries to the front', () async {
      await repository.add('a');
      await repository.add('b');
      await repository.add('a');
      expect(repository.recent, ['a', 'b']);
    });

    test('caps the list at maxEntries dropping the oldest', () async {
      for (var i = 1; i <= RecentSearchesRepository.maxEntries + 1; i++) {
        await repository.add('query-$i');
      }
      expect(repository.recent.length, RecentSearchesRepository.maxEntries);
      expect(repository.recent.first, 'query-${RecentSearchesRepository.maxEntries + 1}');
    });

    test('remove deletes an entry and persists', () async {
      await repository.add('a');
      await repository.add('b');
      await repository.remove('a');
      expect(repository.recent, ['b']);
    });

    test('clear empties the list and persists', () async {
      await repository.add('a');
      await repository.clear();
      expect(repository.recent, isEmpty);
    });

    test('load restores persisted entries from a fresh instance', () async {
      await repository.add('persisted');
      final reloaded = RecentSearchesRepository();
      await reloaded.load();
      expect(reloaded.recent, ['persisted']);
    });
  });
}
