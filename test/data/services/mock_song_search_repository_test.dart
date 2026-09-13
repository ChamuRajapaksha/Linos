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
      final results = await repo.search('');
      expect(results.items, isEmpty);
      expect(results.page, 1);
      expect(results.hasMore, isFalse);
    });

    test('returns empty list for whitespace-only query', () async {
      final results = await repo.search('   ');
      expect(results.items, isEmpty);
      expect(results.page, 1);
      expect(results.hasMore, isFalse);
    });

    test('returns empty list when no songs match', () async {
      final results = await repo.search('xyznonexistent');
      expect(results.items, isEmpty);
      expect(results.page, 1);
      expect(results.hasMore, isFalse);
    });

    test('matches by title substring (case-insensitive)', () async {
      final results = await repo.search('wonderwall');
      expect(results.items.length, 1);
      expect(results.items.first.title, 'Wonderwall');
    });

    test('matches by title substring with different casing', () async {
      final results = await repo.search('Hallelujah');
      expect(results.items.length, 1);
      expect(results.items.first.artist, 'Leonard Cohen');
    });

    test('matches by artist substring (case-insensitive)', () async {
      final results = await repo.search('beatles');
      expect(results.items.length, greaterThanOrEqualTo(4));
      expect(
        results.items.every((s) => s.artist.toLowerCase().contains('beatles')),
        isTrue,
      );
    });

    test('matches partial substring in artist', () async {
      final results = await repo.search('dylan');
      expect(results.items.length, 2);
    });

    test('returns all songs when query is very short but present', () async {
      final results = await repo.search('e');
      expect(results.items.isNotEmpty, isTrue);
    });

    test('trims whitespace from query', () async {
      final results = await repo.search('  creep  ');
      expect(results.items.length, 1);
      expect(results.items.first.id, 'creep');
    });

    test('search delay is exposed as a public constant', () {
      expect(MockSongSearchRepository.searchDelay.inMilliseconds, 250);
    });

    test('page 1 slices to pageSize with hasMore true', () async {
      final results = await repo.search('e');
      expect(results.items.length, MockSongSearchRepository.pageSize);
      expect(results.page, 1);
      expect(results.hasMore, isTrue);
    });

    test('page 2 returns the remaining songs with hasMore false', () async {
      final matching = repo.catalog
          .where((s) =>
              s.title.toLowerCase().contains('e') ||
              s.artist.toLowerCase().contains('e'))
          .length;
      final page1 = await repo.search('e', page: 1);
      final page2 = await repo.search('e', page: 2);

      expect(page1.items.length, MockSongSearchRepository.pageSize);
      expect(page1.hasMore, isTrue);
      expect(page2.items.length, matching - MockSongSearchRepository.pageSize);
      expect(page2.page, 2);
      expect(page2.hasMore, isFalse);
    });

    test('a query matching fewer than pageSize songs has hasMore false',
        () async {
      final results = await repo.search('wonderwall');
      expect(results.items.length, 1);
      expect(results.page, 1);
      expect(results.hasMore, isFalse);
    });
  });
}