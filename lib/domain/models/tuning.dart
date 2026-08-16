import 'note.dart';

class Tuning {
  const Tuning({required this.name, required this.notes});

  final String name;
  final List<Note> notes;

  static const Tuning standard = Tuning(
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

  Note? noteAt(int stringIndex) {
    if (stringIndex < 0 || stringIndex >= notes.length) {
      return null;
    }
    return notes[stringIndex];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Tuning) {
      return false;
    }
    if (other.name != name || other.notes.length != notes.length) {
      return false;
    }
    for (var i = 0; i < notes.length; i++) {
      if (other.notes[i] != notes[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(name, Object.hashAll(notes));
}
