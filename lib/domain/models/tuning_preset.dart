import 'note.dart';
import 'tuning.dart';

class TuningPreset {
  const TuningPreset({
    required this.id,
    required this.name,
    required this.notes,
  });

  final String id;
  final String name;
  final List<Note> notes; // open-string notes, frequencies referenced to A4 = 440

  /// Constructs a note referenced to A4 = 440 from a chromatic name and octave.
  /// Used by custom tunings and when decoding persisted tunings.
  static Note noteFor(String name, int octave) {
    return Note(
      name: name,
      octave: octave,
      frequency: Note.frequencyFor(name, octave),
    );
  }

  static final TuningPreset standard = TuningPreset(
    id: 'standard',
    name: 'Standard',
    notes: Tuning.standard.notes,
  );

  static final TuningPreset dropD = TuningPreset(
    id: 'drop-d',
    name: 'Drop D',
    notes: [
      Note(name: 'D', octave: 2, frequency: Note.frequencyFor('D', 2)),
      Note(name: 'A', octave: 2, frequency: Note.frequencyFor('A', 2)),
      Note(name: 'D', octave: 3, frequency: Note.frequencyFor('D', 3)),
      Note(name: 'G', octave: 3, frequency: Note.frequencyFor('G', 3)),
      Note(name: 'B', octave: 3, frequency: Note.frequencyFor('B', 3)),
      Note(name: 'E', octave: 4, frequency: Note.frequencyFor('E', 4)),
    ],
  );

  static final TuningPreset halfStepDown = TuningPreset(
    id: 'half-step-down',
    name: 'Half-Step Down',
    notes: [
      Note(name: 'D#', octave: 2, frequency: Note.frequencyFor('D#', 2)),
      Note(name: 'G#', octave: 2, frequency: Note.frequencyFor('G#', 2)),
      Note(name: 'C#', octave: 3, frequency: Note.frequencyFor('C#', 3)),
      Note(name: 'F#', octave: 3, frequency: Note.frequencyFor('F#', 3)),
      Note(name: 'A#', octave: 3, frequency: Note.frequencyFor('A#', 3)),
      Note(name: 'D#', octave: 4, frequency: Note.frequencyFor('D#', 4)),
    ],
  );

  static final TuningPreset openG = TuningPreset(
    id: 'open-g',
    name: 'Open G',
    notes: [
      Note(name: 'D', octave: 2, frequency: Note.frequencyFor('D', 2)),
      Note(name: 'G', octave: 2, frequency: Note.frequencyFor('G', 2)),
      Note(name: 'D', octave: 3, frequency: Note.frequencyFor('D', 3)),
      Note(name: 'G', octave: 3, frequency: Note.frequencyFor('G', 3)),
      Note(name: 'B', octave: 3, frequency: Note.frequencyFor('B', 3)),
      Note(name: 'D', octave: 4, frequency: Note.frequencyFor('D', 4)),
    ],
  );

  static final TuningPreset openD = TuningPreset(
    id: 'open-d',
    name: 'Open D',
    notes: [
      Note(name: 'D', octave: 2, frequency: Note.frequencyFor('D', 2)),
      Note(name: 'A', octave: 2, frequency: Note.frequencyFor('A', 2)),
      Note(name: 'D', octave: 3, frequency: Note.frequencyFor('D', 3)),
      Note(name: 'F#', octave: 3, frequency: Note.frequencyFor('F#', 3)),
      Note(name: 'A', octave: 3, frequency: Note.frequencyFor('A', 3)),
      Note(name: 'D', octave: 4, frequency: Note.frequencyFor('D', 4)),
    ],
  );

  static final TuningPreset openE = TuningPreset(
    id: 'open-e',
    name: 'Open E',
    notes: [
      Note(name: 'E', octave: 2, frequency: Note.frequencyFor('E', 2)),
      Note(name: 'B', octave: 2, frequency: Note.frequencyFor('B', 2)),
      Note(name: 'E', octave: 3, frequency: Note.frequencyFor('E', 3)),
      Note(name: 'G#', octave: 3, frequency: Note.frequencyFor('G#', 3)),
      Note(name: 'B', octave: 3, frequency: Note.frequencyFor('B', 3)),
      Note(name: 'E', octave: 4, frequency: Note.frequencyFor('E', 4)),
    ],
  );

  static final TuningPreset dadgad = TuningPreset(
    id: 'dadgad',
    name: 'DADGAD',
    notes: [
      Note(name: 'D', octave: 2, frequency: Note.frequencyFor('D', 2)),
      Note(name: 'A', octave: 2, frequency: Note.frequencyFor('A', 2)),
      Note(name: 'D', octave: 3, frequency: Note.frequencyFor('D', 3)),
      Note(name: 'G', octave: 3, frequency: Note.frequencyFor('G', 3)),
      Note(name: 'A', octave: 3, frequency: Note.frequencyFor('A', 3)),
      Note(name: 'D', octave: 4, frequency: Note.frequencyFor('D', 4)),
    ],
  );

  static final List<TuningPreset> all = [
    standard,
    dropD,
    halfStepDown,
    openG,
    openD,
    openE,
    dadgad,
  ];

  static TuningPreset? byId(String id) {
    for (final preset in all) {
      if (preset.id == id) {
        return preset;
      }
    }
    return null;
  }

  Tuning tuningFor(double a4Reference) {
    final ratio = a4Reference / Note.a4Reference;
    return Tuning(
      name: name,
      notes: [
        for (final note in notes)
          Note(
            name: note.name,
            octave: note.octave,
            frequency: note.frequency * ratio,
          ),
      ],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! TuningPreset) {
      return false;
    }
    if (other.id != id || other.name != name || other.notes.length != notes.length) {
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
  int get hashCode => Object.hash(id, name, Object.hashAll(notes));
}
