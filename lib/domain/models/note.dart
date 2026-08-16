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
