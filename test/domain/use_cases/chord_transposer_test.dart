import 'package:flutter_test/flutter_test.dart';
import 'package:linos/domain/use_cases/chord_transposer.dart';

void main() {
  final t = ChordTransposer();

  group('sharp roots', () {
    test('C +1 = C#', () {
      expect(t.transpose('C', 1), 'C#');
    });

    test('G +2 = A', () {
      expect(t.transpose('G', 2), 'A');
    });

    test('F# +1 = G', () {
      expect(t.transpose('F#', 1), 'G');
    });

    test('C# +11 = C', () {
      expect(t.transpose('C#', 11), 'C');
    });
  });

  group('flat roots', () {
    test('Bb +1 = B', () {
      expect(t.transpose('Bb', 1), 'B');
    });

    test('Eb -2 = C#', () {
      expect(t.transpose('Eb', -2), 'C#');
    });

    test('Db +2 = D#', () {
      expect(t.transpose('Db', 2), 'D#');
    });
  });

  group('octave wrap', () {
    test('B +1 = C', () {
      expect(t.transpose('B', 1), 'C');
    });

    test('C -1 = B', () {
      expect(t.transpose('C', -1), 'B');
    });

    test('A +3 = C', () {
      expect(t.transpose('A', 3), 'C');
    });

    test('G -12 = G', () {
      expect(t.transpose('G', -12), 'G');
    });
  });

  group('common suffixes', () {
    test('Cm +2 = Dm', () {
      expect(t.transpose('Cm', 2), 'Dm');
    });

    test('G7 +1 = G#7', () {
      expect(t.transpose('G7', 1), 'G#7');
    });

    test('Amaj7 +2 = Bmaj7', () {
      expect(t.transpose('Amaj7', 2), 'Bmaj7');
    });

    test('Dsus4 +1 = D#sus4', () {
      expect(t.transpose('Dsus4', 1), 'D#sus4');
    });

    test('E9 +1 = F9', () {
      expect(t.transpose('E9', 1), 'F9');
    });

    test('Cadd9 +3 = D#add9', () {
      expect(t.transpose('Cadd9', 3), 'D#add9');
    });

    test('Am +3 = Cm', () {
      expect(t.transpose('Am', 3), 'Cm');
    });
  });

  group('slash chords', () {
    test('G/B +2 = A/C#', () {
      expect(t.transpose('G/B', 2), 'A/C#');
    });

    test('C/E +12 = C/E', () {
      expect(t.transpose('C/E', 12), 'C/E');
    });
  });

  group('diminished and augmented', () {
    test('Adim7 +2 = Bdim7', () {
      expect(t.transpose('Adim7', 2), 'Bdim7');
    });

    test('Caug +4 = Eaug', () {
      expect(t.transpose('Caug', 4), 'Eaug');
    });

    test('Edim +1 = Fdim', () {
      expect(t.transpose('Edim', 1), 'Fdim');
    });
  });

  group('pass-through', () {
    test('N.C. unchanged', () {
      expect(t.transpose('N.C.', 5), 'N.C.');
    });

    test('empty string unchanged', () {
      expect(t.transpose('', 3), '');
    });

    test('unknown garbage unchanged at positive shift', () {
      expect(t.transpose('xyz', 4), 'xyz');
    });

    test('unknown garbage unchanged at negative shift', () {
      expect(t.transpose('xyz', -3), 'xyz');
    });

    test('semitones == 0 returns identical input', () {
      expect(t.transpose('Cm7', 0), 'Cm7');
      expect(t.transpose('xyz', 0), 'xyz');
    });
  });

  group('full octave', () {
    test('transposing by +12 returns the original', () {
      expect(t.transpose('C', 12), 'C');
      expect(t.transpose('F#', 12), 'F#');
      expect(t.transpose('Bb', 12), 'A#');
    });

    test('transposing by -12 returns the original', () {
      expect(t.transpose('C', -12), 'C');
      expect(t.transpose('F#', -12), 'F#');
      expect(t.transpose('Bb', -12), 'A#');
    });
  });

  group('chain test', () {
    test('consecutive shifts compose correctly', () {
      expect(t.transpose('C', 1), 'C#');
      expect(t.transpose('C#', 1), 'D');
      expect(t.transpose('D', 5), 'G');
      expect(t.transpose('G', 6), 'C#');
      expect(t.transpose('C#', -1), 'C');
      expect(t.transpose('C', 7), 'G');
      expect(t.transpose('G', 5), 'C');
    });
  });
}
