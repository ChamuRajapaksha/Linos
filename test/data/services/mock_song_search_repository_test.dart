import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/services/mock_song_search_repository.dart';

void main() {
  final repo = MockSongSearchRepository();

  group('MockSongSearchRepository.catalog', () {
    test('contains between 15 and 20 songs', () {
      expect(repo.catalog.length, inInclusiveRange(15, 20));
    });

    test('every song id is unique', () {
      final ids = repo.catalog.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('MockSongSearchRepository.search', () {
    test('returns empty list for empty query', () async {
      expect(await repo.search(''), isEmpty);
    });

    test('returns empty list for whitespace-only query', () async {
      expect(await repo.search('   '), isEmpty);
    });

    test('returns empty list when no songs match', () async {
      expect(await repo.search('xyznonexistent'), isEmpty);
    });

    test('matches by title substring (case-insensitive)', () async {
      final results = await repo.search('wonderwall');
      expect(results.length, 1);
      expect(results.first.title, 'Wonderwall');
    });

    test('matches by title substring with different casing', () async {
      final results = await repo.search('Hallelujah');
      expect(results.length, 1);
      expect(results.first.artist, 'Leonard Cohen');
    });

    test('matches by artist substring (case-insensitive)', () async {
      final results = await repo.search('beatles');
      expect(results.length, greaterThanOrEqualTo(4));
      expect(
        results.every((s) => s.artist.toLowerCase().contains('beatles')),
        isTrue,
      );
    });

    test('matches partial substring in artist', () async {
      final results = await repo.search('dylan');
      expect(results.length, 2);
    });

    test('returns all songs when query is very short but present', () async {
      final results = await repo.search('e');
      expect(results.isNotEmpty, isTrue);
    });

    test('trims whitespace from query', () async {
      final results = await repo.search('  creep  ');
      expect(results.length, 1);
      expect(results.first.id, 'creep');
    });

    test('search delay is exposed as a public constant', () {
      expect(MockSongSearchRepository.searchDelay.inMilliseconds, 250);
    });
  });
}
