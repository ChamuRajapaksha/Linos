import 'package:flutter_test/flutter_test.dart';
import 'package:linos/domain/models/note.dart';

void main() {
  group('Note', () {
    test('midiNumber is correct', () {
      const a4 = Note(name: 'A', octave: 4, frequency: 440.0);
      const e2 = Note(name: 'E', octave: 2, frequency: 82.41);
      const fSharp3 = Note(name: 'F#', octave: 3, frequency: 185.0);
      const c0 = Note(name: 'C', octave: 0, frequency: 16.35);

      expect(a4.midiNumber, 69);
      expect(e2.midiNumber, 40);
      expect(fSharp3.midiNumber, 54);
      expect(c0.midiNumber, 12);
    });

    test('label is formatted as name + octave', () {
      const e2 = Note(name: 'E', octave: 2, frequency: 82.41);
      const fSharp3 = Note(name: 'F#', octave: 3, frequency: 185.0);

      expect(e2.label, 'E2');
      expect(fSharp3.label, 'F#3');
    });

    test('a4Reference is 440 Hz', () {
      expect(Note.a4Reference, 440.0);
    });

    test('chromaticNotes contains all 12 names', () {
      expect(
        Note.chromaticNotes,
        ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'],
      );
    });

    test('equality compares all three fields', () {
      const a4 = Note(name: 'A', octave: 4, frequency: 440.0);
      expect(a4, const Note(name: 'A', octave: 4, frequency: 440.0));
      expect(a4 == const Note(name: 'A', octave: 4, frequency: 441.0), isFalse);
      expect(a4 == const Note(name: 'A', octave: 5, frequency: 440.0), isFalse);
      expect(a4 == const Note(name: 'A#', octave: 4, frequency: 440.0), isFalse);
      expect(a4.hashCode, const Note(name: 'A', octave: 4, frequency: 440.0).hashCode);
    });
  });
}