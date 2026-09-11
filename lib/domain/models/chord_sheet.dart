sealed class SheetLine {
  const SheetLine();
}

class SongSection extends SheetLine {
  const SongSection(this.name);

  final String name;

  String get label => name.toUpperCase();
}

class LyricLine extends SheetLine {
  const LyricLine(this.words);

  final List<WordChord> words;
}

class WordChord {
  const WordChord({required this.word, this.chord});

  final String word;
  final String? chord;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! WordChord) {
      return false;
    }
    return other.word == word && other.chord == chord;
  }

  @override
  int get hashCode => Object.hash(word, chord);
}

class ChordSheet {
  const ChordSheet({
    required this.title,
    required this.artist,
    this.key,
    required this.lines,
  });

  final String title;
  final String artist;
  final String? key;
  final List<SheetLine> lines;
}
