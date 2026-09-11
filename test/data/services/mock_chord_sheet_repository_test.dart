import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/services/mock_chord_sheet_repository.dart';
import 'package:linos/data/services/mock_song_search_repository.dart';
import 'package:linos/domain/models/chord_sheet.dart';
import 'package:linos/domain/models/song.dart';

void main() {
  final repo = MockChordSheetRepository();
  final searchRepo = MockSongSearchRepository();

  group('MockChordSheetRepository.bundledSongIds', () {
    test('is not empty', () {
      expect(repo.bundledSongIds, isNotEmpty);
    });

    test('every bundled id exists in the search catalog', () {
      final catalogIds = searchRepo.catalog.map((s) => s.id).toSet();
      for (final id in repo.bundledSongIds) {
        expect(catalogIds, contains(id));
      }
    });
  });

  group('MockChordSheetRepository.fetch', () {
    test('returns a sheet for a bundled song', () async {
      final song = searchRepo.catalog.firstWhere(
        (s) => s.id == 'wonderwall',
      );
      final sheet = await repo.fetch(song);
      expect(sheet.title, 'Wonderwall');
      expect(sheet.artist, 'Oasis');
    });

    test('sheet title and artist match the song', () async {
      final song = searchRepo.catalog.firstWhere(
        (s) => s.id == 'hallelujah',
      );
      final sheet = await repo.fetch(song);
      expect(sheet.title, song.title);
      expect(sheet.artist, song.artist);
    });

    test('throws StateError for an unknown song', () async {
      const unknown = Song(id: 'nope', title: 'Nope', artist: 'Nobody');
      expect(() => repo.fetch(unknown), throwsStateError);
    });

    test('fetch delay is exposed as a public constant', () {
      expect(MockChordSheetRepository.fetchDelay.inMilliseconds, 200);
    });
  });

  group('Sheet structure', () {
    late List<ChordSheet> sheets;

    setUpAll(() async {
      sheets = [];
      for (final id in repo.bundledSongIds) {
        final song = searchRepo.catalog.firstWhere((s) => s.id == id);
        sheets.add(await repo.fetch(song));
      }
    });

    test('every sheet contains at least one SongSection', () {
      for (final sheet in sheets) {
        final hasSection = sheet.lines.any((l) => l is SongSection);
        expect(hasSection, isTrue, reason: '${sheet.title} missing SongSection');
      }
    });

    test('every sheet contains at least one LyricLine', () {
      for (final sheet in sheets) {
        final hasLyric = sheet.lines.any((l) => l is LyricLine);
        expect(hasLyric, isTrue, reason: '${sheet.title} missing LyricLine');
      }
    });

    test('WordChord words are non-empty in every LyricLine', () {
      for (final sheet in sheets) {
        for (final line in sheet.lines) {
          if (line is LyricLine) {
            for (final wc in line.words) {
              expect(wc.word.isNotEmpty, isTrue,
                  reason: '${sheet.title} has empty word');
            }
          }
        }
      }
    });

    test(
      'every distinct chord is within the expected 12-chord set',
      () {
        const expectedChords = {
          'A',
          'Am',
          'Bm',
          'C',
          'D',
          'Dm',
          'E',
          'Em',
          'F',
          'G',
          'F#m',
          'Bb',
        };
        final usedChords = <String>{};
        for (final sheet in sheets) {
          for (final line in sheet.lines) {
            if (line is LyricLine) {
              for (final wc in line.words) {
                if (wc.chord != null) usedChords.add(wc.chord!);
              }
            }
          }
        }
        expect(
          usedChords.difference(expectedChords),
          isEmpty,
          reason: 'Unexpected chords found: ${usedChords.difference(expectedChords)}',
        );
        expect(usedChords.length, 12,
            reason: 'Expected 12 distinct chords, found ${usedChords.length}: $usedChords');
      },
    );
  });
}
