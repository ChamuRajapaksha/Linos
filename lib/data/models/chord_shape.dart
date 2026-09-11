/// An immutable chord shape for a 6-string guitar.
class ChordShape {
  const ChordShape({required this.name, required this.frets, this.baseFret = 1});

  final String name;

  /// Fret to finger for the 6 strings low-E→high-E.
  /// 0 = open string, -1 = muted (string not played).
  final List<int> frets;

  /// Fret number of the top line of the diagram (for barre shapes). Default 1.
  final int baseFret;
}

/// Common open and barre chord shapes, keyed by display name.
const Map<String, ChordShape> chordShapes = {
  'A': ChordShape(name: 'A', frets: [0, 2, 2, 2, 0, 0]),
  'Am': ChordShape(name: 'Am', frets: [0, 2, 2, 1, 0, 0]),
  'C': ChordShape(name: 'C', frets: [-1, 3, 2, 0, 1, 0]),
  'D': ChordShape(name: 'D', frets: [-1, -1, 0, 2, 3, 2]),
  'Dm': ChordShape(name: 'Dm', frets: [-1, -1, 0, 2, 3, 1]),
  'E': ChordShape(name: 'E', frets: [0, 2, 2, 1, 0, 0]),
  'Em': ChordShape(name: 'Em', frets: [0, 2, 2, 0, 0, 0]),
  'G': ChordShape(name: 'G', frets: [3, 2, 0, 0, 0, 3]),
  'F': ChordShape(name: 'F', frets: [1, 3, 3, 2, 1, 1], baseFret: 1),
  'Bm': ChordShape(name: 'Bm', frets: [2, 4, 4, 3, 2, 2], baseFret: 2),
};
