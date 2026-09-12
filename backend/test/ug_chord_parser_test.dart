import 'package:linos_backend/domain/chord_sheet.dart';
import 'package:linos_backend/scraping/ug_chord_parser.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  const parser = UgChordParser();

  group('parse', () {
    test('wonderwall meta, sections and chord mapping', () {
      final sheet = parser.parse(readFixture('tab_wonderwall.html'));

      expect(sheet.title, 'Wonderwall');
      expect(sheet.artist, 'Oasis');
      expect(sheet.key, 'F#m');

      final sections = sheet.lines
          .whereType<SectionLine>()
          .map((line) => line.name)
          .toList();
      expect(sections, containsAll(['Verse 1', 'Chorus']));

      final words = sheet.lines
          .whereType<LyricLine>()
          .expand((line) => line.words)
          .toList();
      expect(words.any((w) => w.word == 'Today' && w.chord == 'F#m7'), isTrue);
    });

    test('knockin skips fretboard charts and keeps section markers', () {
      final sheet = parser.parse(readFixture('tab_knockin.html'));

      expect(sheet.title, 'Knockin On Heavens Door');
      expect(sheet.artist, 'Bob Dylan');
      expect(sheet.key, 'G');

      final words = sheet.lines
          .whereType<LyricLine>()
          .expand((line) => line.words)
          .toList();
      expect(words.every((w) => !w.word.contains('x')), isTrue);

      final sections = sheet.lines
          .whereType<SectionLine>()
          .map((line) => line.name)
          .toList();
      expect(sections, contains('Intro'));
    });

    test('html without a js-store throws ChordSheetParseException', () {
      expect(
        () => parser.parse('<html><body></body></html>'),
        throwsA(isA<ChordSheetParseException>()),
      );
    });
  });

  group('parseChordPro', () {
    test('section markers become SectionLine', () {
      final lines = parser.parseChordPro('[Verse 3]');

      expect(lines, hasLength(1));
      expect(lines.single, isA<SectionLine>());
      expect((lines.single as SectionLine).name, 'Verse 3');
    });

    test('chord-only line attaches chords to lyric words', () {
      final lines = parser.parseChordPro('[ch]C[/ch]      [ch]G[/ch]\n Hello world');

      expect(lines, hasLength(1));
      final line = lines.single as LyricLine;
      expect(line.words, hasLength(2));
      expect(line.words.first.word, 'Hello');
      expect(line.words.first.chord, 'C');
      expect(line.words.last.word, 'world');
      expect(line.words.last.chord, 'G');
    });

    test('gauge-style tab wrapper is ignored', () {
      expect(parser.parseChordPro('[tab]G     3-x-0-0-0-3[/tab]'), isEmpty);
    });

    test('empty content produces no lines', () {
      expect(parser.parseChordPro(''), isEmpty);
      expect(parser.parseChordPro(' \n  \t \n'), isEmpty);
    });

    test('inline chords attach to the word they are column-aligned with', () {
      final lines = parser.parseChordPro('[ch]C[/ch]C [ch]G[/ch]G');

      expect(lines, hasLength(1));
      final line = lines.single as LyricLine;
      expect(line.words, hasLength(2));
      expect(line.words.first.word, 'C');
      expect(line.words.first.chord, 'C');
      expect(line.words.last.word, 'G');
    });
  });
}