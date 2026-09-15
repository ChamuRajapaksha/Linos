const _sharpChromatic = [
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

const _flatToSharp = {
  'Bb': 'A#',
  'Db': 'C#',
  'Eb': 'D#',
  'Gb': 'F#',
  'Ab': 'G#',
};

int _rootIndex(String root) {
  final sharp = _flatToSharp[root];
  if (sharp != null) {
    return _sharpChromatic.indexOf(sharp);
  }
  return _sharpChromatic.indexOf(root);
}

String? _transposeNote(String note, int semitones) {
  final index = _rootIndex(note);
  if (index < 0) return null;
  final newIndex = (index + semitones) % 12;
  return _sharpChromatic[newIndex];
}

class ChordTransposer {
  const ChordTransposer();

  /// Transposes [chord] by [semitones] semitones, preserving suffix and slash bass.
  String transpose(String chord, int semitones) {
    if (semitones == 0 || chord.isEmpty) return chord;

    final match = RegExp(
      r'^([A-G][#b]?)(.*)',
    ).firstMatch(chord);
    if (match == null) return chord;

    final root = match.group(1)!;
    final suffix = match.group(2)!;

    final newRoot = _transposeNote(root, semitones);
    if (newRoot == null) return chord;

    if (suffix.startsWith('/')) {
      final bassRaw = suffix.substring(1);
      final newBass = _transposeNote(bassRaw, semitones);
      if (newBass == null) return chord;
      return '$newRoot/$newBass';
    }

    return '$newRoot$suffix';
  }
}
