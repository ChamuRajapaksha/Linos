import 'package:flutter_test/flutter_test.dart';
import 'package:linos/domain/models/note.dart';
import 'package:linos/domain/models/tuning.dart';

void main() {
  group('Tuning.standard', () {
    test('has 6 notes', () {
      expect(Tuning.standard.notes.length, 6);
    });

    test('has correct names and octaves', () {
      final expectedLabels = ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'];
      expect(
        Tuning.standard.notes.map((n) => n.label).toList(),
        expectedLabels,
      );
    });

    test('has correct frequencies', () {
      final expectedFrequencies = [82.41, 110.0, 146.83, 196.0, 246.94, 329.63];
      expect(
        Tuning.standard.notes.map((n) => n.frequency).toList(),
        expectedFrequencies,
      );
    });

    test('notes have correct midi numbers', () {
      final expectedMidi = [40, 45, 50, 55, 59, 64];
      expect(
        Tuning.standard.notes.map((n) => n.midiNumber).toList(),
        expectedMidi,
      );
    });

    test('name is Standard', () {
      expect(Tuning.standard.name, 'Standard');
    });
  });

  group('Tuning.noteAt', () {
    test('returns note for valid indices', () {
      expect(Tuning.standard.noteAt(0), const Note(name: 'E', octave: 2, frequency: 82.41));
      expect(Tuning.standard.noteAt(5), const Note(name: 'E', octave: 4, frequency: 329.63));
    });

    test('returns null for out of range indices', () {
      expect(Tuning.standard.noteAt(-1), isNull);
      expect(Tuning.standard.noteAt(6), isNull);
      expect(Tuning.standard.noteAt(100), isNull);
    });
  });

  group('Tuning.retunedTo', () {
    test('at 440 returns the same frequencies', () {
      final retuned = Tuning.standard.retunedTo(440);
      expect(retuned.name, 'Standard');
      for (var i = 0; i < Tuning.standard.notes.length; i++) {
        expect(
          retuned.notes[i].frequency,
          closeTo(Tuning.standard.notes[i].frequency, 1e-9),
        );
      }
    });

    test('shifts all frequencies by the reference ratio', () {
      final retuned = Tuning.standard.retunedTo(442);
      expect(retuned.notes.length, 6);
      expect(retuned.notes[0].label, 'E2');
      expect(retuned.notes[0].frequency, closeTo(82.41 * (442 / 440), 0.01));
      expect(retuned.notes[5].frequency, closeTo(329.63 * (442 / 440), 0.01));
    });

    test('at 438 shifts frequencies down', () {
      final retuned = Tuning.standard.retunedTo(438);
      expect(retuned.notes[1].frequency, closeTo(110.0 * (438 / 440), 0.01));
    });
  });

  group('Tuning equality', () {
    test('equal for same name and notes', () {
      const other = Tuning(
        name: 'Standard',
        notes: [
          Note(name: 'E', octave: 2, frequency: 82.41),
          Note(name: 'A', octave: 2, frequency: 110.0),
          Note(name: 'D', octave: 3, frequency: 146.83),
          Note(name: 'G', octave: 3, frequency: 196.0),
          Note(name: 'B', octave: 3, frequency: 246.94),
          Note(name: 'E', octave: 4, frequency: 329.63),
        ],
      );
      expect(Tuning.standard, other);
      expect(Tuning.standard.hashCode, other.hashCode);
    });

    test('not equal for different notes', () {
      const other = Tuning(
        name: 'Standard',
        notes: [
          Note(name: 'E', octave: 2, frequency: 82.41),
          Note(name: 'A', octave: 2, frequency: 110.0),
          Note(name: 'D', octave: 3, frequency: 146.83),
          Note(name: 'G', octave: 3, frequency: 196.0),
          Note(name: 'B', octave: 3, frequency: 246.94),
          Note(name: 'E', octave: 4, frequency: 330.0),
        ],
      );
      expect(Tuning.standard == other, isFalse);
    });

    test('not equal for different name', () {
      final other = Tuning(name: 'Drop D', notes: Tuning.standard.notes);
      expect(Tuning.standard == other, isFalse);
    });
  });
}