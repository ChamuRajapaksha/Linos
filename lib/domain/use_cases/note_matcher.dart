import 'dart:math' as math;

import '../models/frequency.dart';
import '../models/note.dart';

class NoteMatch {
  const NoteMatch({
    required this.note,
    required this.centsOffset,
    required this.midiNumber,
  });

  final Note note;
  final double centsOffset;
  final int midiNumber;

  @override
  bool operator ==(Object other) {
    return other is NoteMatch &&
        other.note == note &&
        other.centsOffset == centsOffset &&
        other.midiNumber == midiNumber;
  }

  @override
  int get hashCode => Object.hash(note, centsOffset, midiNumber);
}

class NoteMatcher {
  const NoteMatcher({this.a4Reference = Note.a4Reference});

  final double a4Reference;

  NoteMatch match(Frequency frequency) {
    final midi = (12 * math.log(frequency.value / a4Reference) / math.ln2 + 69)
        .round();
    final octave = (midi ~/ 12) - 1;
    final semitone = midi % 12;
    final name = Note.chromaticNotes[semitone];
    final noteFrequency =
        a4Reference * math.pow(2, (midi - 69) / 12).toDouble();
    final cents =
        1200 * math.log(frequency.value / noteFrequency) / math.ln2;
    return NoteMatch(
      note: Note(name: name, octave: octave, frequency: noteFrequency),
      centsOffset: cents,
      midiNumber: midi,
    );
  }
}
