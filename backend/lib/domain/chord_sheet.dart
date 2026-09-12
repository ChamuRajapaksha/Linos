sealed class SongLine {
  const SongLine();
}

class SectionLine extends SongLine {
  const SectionLine(this.name);

  final String name;

  String get label => name.toUpperCase();
}

class LyricLine extends SongLine {
  const LyricLine(this.words);

  final List<WordChord> words;
}

class WordChord {
  const WordChord({required this.word, this.chord});

  final String word;
  final String? chord;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordChord && word == other.word && chord == other.chord);

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
  final List<SongLine> lines;

  Map<String, Object?> toJson() => {
    'title': title,
    'artist': artist,
    if (key != null) 'key': key,
    'lines': songLinesToJson(lines),
  };
}

List<Map<String, Object?>> songLinesToJson(List<SongLine> lines) {
  return lines.map((line) {
    return switch (line) {
      SectionLine(:final name) => {'type': 'section', 'name': name},
      LyricLine(:final words) => {
        'type': 'lyric',
        'words': words.map((w) {
          return {'word': w.word, if (w.chord != null) 'chord': w.chord};
        }).toList(),
      },
    };
  }).toList();
}

List<SongLine> songLinesFromJson(List<Map<String, dynamic>> lines) {
  return lines.map((line) {
    return switch (line['type']) {
      'section' => SectionLine(line['name'] as String),
      'lyric' => LyricLine(
        (line['words'] as List).map((word) {
          final w = word as Map<String, dynamic>;
          return WordChord(
            word: w['word'] as String,
            chord: w['chord'] as String?,
          );
        }).toList(),
      ),
      _ => throw FormatException('Unknown line type: ${line['type']}'),
    };
  }).toList();
}
