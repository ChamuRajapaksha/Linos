import 'package:linos_backend/data/chord_sheet_cache_dao.dart';
import 'package:linos_backend/data/song_cache_dao.dart';
import 'package:linos_backend/domain/chord_sheet.dart';
import 'package:linos_backend/domain/song.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('SongCacheDao', () {
    late Database db;
    late SongCacheDao dao;

    setUp(() {
      db = createTestDb();
      dao = SongCacheDao(db);
    });

    tearDown(() => db.close());

    test('upsert, getById, has and case-insensitive search', () async {
      await dao.upsert(const [
        CachedSong(
          song: Song(id: '1', title: 'Wonderwall', artist: 'Oasis'),
          tabUrl:
              'https://tabs.ultimate-guitar.com/tab/oasis/wonderwall-chords-6125',
        ),
        CachedSong(
          song: Song(id: '2', title: 'Champagne Supernova', artist: 'Oasis'),
          tabUrl: 'https://tabs.ultimate-guitar.com/tab/oasis/champagne-supernova-chords-2',
        ),
        CachedSong(
          song: Song(id: '3', title: 'Backbeat', artist: 'The Beatles'),
          tabUrl: 'https://tabs.ultimate-guitar.com/tab/beatles/backbeat-chords-3',
        ),
      ]);

      final first = await dao.getById('1');
      expect(first, isNotNull);
      expect(first!.song.title, 'Wonderwall');
      expect(first.song.artist, 'Oasis');
      expect(first.tabUrl,
          'https://tabs.ultimate-guitar.com/tab/oasis/wonderwall-chords-6125');

      expect(await dao.has('2'), isTrue);
      expect(await dao.has('999'), isFalse);

      final byTitle = await dao.search('wonder');
      expect(byTitle.map((c) => c.song.id), ['1']);

      final byArtist = await dao.search('oasis');
      expect(byArtist.map((c) => c.song.id), unorderedEquals(['1', '2']));

      final upper = await dao.search('WONDER');
      expect(upper.map((c) => c.song.id), contains('1'));
    });

    test('remove deletes the song row', () async {
      await dao.upsert(const [
        CachedSong(song: Song(id: '7', title: 'X', artist: 'Y'), tabUrl: 'u'),
      ]);

      expect(await dao.has('7'), isTrue);
      await dao.remove('7');

      expect(await dao.has('7'), isFalse);
      expect(await dao.getById('7'), isNull);
    });
  });

  group('ChordSheetCacheDao', () {
    late Database db;
    late SongCacheDao songs;
    late ChordSheetCacheDao sheets;

    setUp(() {
      db = createTestDb();
      songs = SongCacheDao(db);
      sheets = ChordSheetCacheDao(db);
    });

    tearDown(() => db.close());

    test('upsert and getById round-trip a chord sheet', () async {
      await songs.upsert(const [
        CachedSong(
          song: Song(id: '1', title: 'Wonderwall', artist: 'Oasis'),
          tabUrl:
              'https://tabs.ultimate-guitar.com/tab/oasis/wonderwall-chords-6125',
        ),
      ]);
      await sheets.upsert(
        songId: '1',
        sheet: const ChordSheet(
          title: 'Wonderwall',
          artist: 'Oasis',
          key: 'F#m',
          lines: [
            SectionLine('Verse 1'),
            LyricLine([WordChord(word: 'Today', chord: 'F#m7')]),
          ],
        ),
      );

      final sheet = await sheets.getById('1');
      expect(sheet, isNotNull);
      expect(sheet!.title, 'Wonderwall');
      expect(sheet.artist, 'Oasis');
      expect(sheet.key, 'F#m');
      expect(sheet.lines, hasLength(2));
      expect(sheet.lines.first, isA<SectionLine>());
      expect((sheet.lines.first as SectionLine).name, 'Verse 1');
      expect(sheet.lines.last, isA<LyricLine>());
      expect((sheet.lines.last as LyricLine).words,
          const [WordChord(word: 'Today', chord: 'F#m7')]);
    });

    test('a null-key sheet round-trips key as null', () async {
      await songs.upsert(const [
        CachedSong(song: Song(id: '2', title: 'X', artist: 'Y'), tabUrl: 'u'),
      ]);
      await sheets.upsert(
        songId: '2',
        sheet: const ChordSheet(
          title: 'X',
          artist: 'Y',
          lines: [SectionLine('Intro')],
        ),
      );

      final sheet = await sheets.getById('2');
      expect(sheet, isNotNull);
      expect(sheet!.key, isNull);
      expect(sheet.lines.single, isA<SectionLine>());
    });

    test('removing a song cascades to its cached chord sheet', () async {
      db.execute('PRAGMA foreign_keys = ON;');
      await songs.upsert(const [
        CachedSong(song: Song(id: '3', title: 'X', artist: 'Y'), tabUrl: 'u'),
      ]);
      await sheets.upsert(
        songId: '3',
        sheet: const ChordSheet(title: 'X', artist: 'Y', lines: []),
      );

      expect(await sheets.has('3'), isTrue);
      await songs.remove('3');

      expect(await songs.has('3'), isFalse);
      expect(await sheets.has('3'), isFalse);
      expect(await sheets.getById('3'), isNull);
    });
  });
}