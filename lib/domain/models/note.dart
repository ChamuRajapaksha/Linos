import 'dart:math' show pow;

class Note {
  const Note({
    required this.name,
    required this.octave,
    required this.frequency,
  });

  final String name;
  final int octave;
  final double frequency;

  static const double a4Reference = 440.0;

  static const List<String> chromaticNotes = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  int get midiNumber {
    final semitone = chromaticNotes.indexOf(name);
    return (octave + 1) * 12 + semitone;
  }

  static double frequencyFor(
    String name,
    int octave, {
    double a4Reference = Note.a4Reference,
  }) {
    final midi = (octave + 1) * 12 + chromaticNotes.indexOf(name);
    return a4Reference * pow(2, (midi - 69) / 12);
  }

  String get label => '$name$octave';

  @override
  bool operator ==(Object other) {
    return other is Note &&
        other.name == name &&
        other.octave == octave &&
        other.frequency == frequency;
  }

  @override
  int get hashCode => Object.hash(name, octave, frequency);
}
