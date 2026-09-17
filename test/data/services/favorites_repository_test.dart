import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/services/favorites_repository.dart';
import 'package:linos/domain/models/song.dart';
import 'package:shared_preferences/shared_preferences.dart';

Song _song(String id) => Song(id: id, title: 'Title $id', artist: 'Artist $id');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FavoritesRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = FavoritesRepository();
    await repository.load();
  });

  group('FavoritesRepository', () {
    test('starts empty and does not contain any song', () {
      expect(repository.favorites, isEmpty);
      expect(repository.contains(_song('a')), isFalse);
    });

    test('add stores a song and dedupes duplicates', () async {
      await repository.add(_song('a'));
      await repository.add(_song('a'));
      expect(repository.favorites.length, 1);
      expect(repository.contains(_song('a')), isTrue);
    });

    test('add notifies listeners', () async {
      var notified = 0;
      repository.addListener(() => notified++);
      await repository.add(_song('b'));
      expect(notified, 1);
    });

    test('toggle adds unknown songs and removes known ones', () async {
      await repository.toggle(_song('c'));
      expect(repository.contains(_song('c')), isTrue);

      await repository.toggle(_song('c'));
      expect(repository.contains(_song('c')), isFalse);
      expect(repository.favorites, isEmpty);
    });

    test('remove removes an existing song', () async {
      await repository.add(_song('d'));
      await repository.remove(_song('d'));
      expect(repository.contains(_song('d')), isFalse);
      expect(repository.favorites, isEmpty);
    });

    test('remove of an unknown song is a no-op', () async {
      await repository.remove(_song('nope'));
      expect(repository.favorites, isEmpty);
    });

    test('favorites persist and reload across repository instances', () async {
      await repository.add(_song('persisted'));
      await repository.add(_song('persisted2'));

      final reloaded = FavoritesRepository();
      await reloaded.load();
      expect(reloaded.favorites.length, 2);
      expect(reloaded.contains(_song('persisted')), isTrue);
      expect(reloaded.contains(_song('persisted2')), isTrue);
    });
  });
}
