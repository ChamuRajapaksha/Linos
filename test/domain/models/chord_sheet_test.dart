import 'package:flutter_test/flutter_test.dart';
import 'package:linos/domain/models/chord_sheet.dart';

void main() {
  group('WordChord', () {
    test('holds word and optional chord', () {
      const withChord = WordChord(word: 'hello', chord: 'C');
      const withoutChord = WordChord(word: 'world');

      expect(withChord.word, 'hello');
      expect(withChord.chord, 'C');
      expect(withoutChord.chord, isNull);
    });

    test('equality compares word and chord', () {
      const a = WordChord(word: 'hello', chord: 'C');
      const b = WordChord(word: 'hello', chord: 'C');
      const c = WordChord(word: 'hello', chord: 'G');
      const d = WordChord(word: 'hello');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      expect(a == d, isFalse);
    });
  });

  group('SongSection', () {
    test('label returns uppercased name', () {
      const section = SongSection('Verse');
      expect(section.name, 'Verse');
      expect(section.label, 'VERSE');
    });
  });

  group('ChordSheet', () {
    test('holds metadata and mixed sheet lines', () {
      const sheet = ChordSheet(
        title: 'Wonderwall',
        artist: 'Oasis',
        key: 'C Maj',
        lines: [
          SongSection('Verse'),
          LyricLine([
            WordChord(word: 'Today', chord: 'C'),
            WordChord(word: 'is', chord: 'G'),
            WordChord(word: 'gonna'),
          ]),
          SongSection('Chorus'),
          LyricLine([
            WordChord(word: 'Maybe', chord: 'Am'),
            WordChord(word: 'you'),
            WordChord(word: 'found', chord: 'F'),
          ]),
        ],
      );

      expect(sheet.title, 'Wonderwall');
      expect(sheet.artist, 'Oasis');
      expect(sheet.key, 'C Maj');
      expect(sheet.lines.length, 4);
      expect(sheet.lines[0], isA<SongSection>());
      expect(sheet.lines[1], isA<LyricLine>());
      expect(sheet.lines[2], isA<SongSection>());
      expect(sheet.lines[3], isA<LyricLine>());
    });

    test('key can be null', () {
      const sheet = ChordSheet(
        title: 'Song',
        artist: 'Artist',
        lines: [],
      );
      expect(sheet.key, isNull);
    });

    test('LyricLine words are accessible', () {
      const line = LyricLine([
        WordChord(word: 'hey', chord: 'Am'),
        WordChord(word: 'ho'),
      ]);
      expect(line.words.length, 2);
      expect(line.words[0].chord, 'Am');
      expect(line.words[1].chord, isNull);
    });
  });
}
