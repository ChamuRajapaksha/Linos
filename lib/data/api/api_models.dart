import '../../domain/models/chord_sheet.dart';
import '../../domain/models/song.dart';

/// A paginated batch of songs from `GET /api/search`.
///
/// Only [items] feeds the current search UI; [page]/[hasMore] back the
/// infinite-scroll milestone.
class SearchResponse {
  const SearchResponse({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) => SearchResponse(
    items: (json['items'] as List)
        .map((e) => SongDto.fromJson(e as Map<String, dynamic>).toDomain())
        .toList(),
    page: json['page'] as int,
    hasMore: json['hasMore'] as bool,
  );

  final List<Song> items;
  final int page;
  final bool hasMore;
}

class SongDto {
  const SongDto({required this.id, required this.title, required this.artist});

  factory SongDto.fromJson(Map<String, dynamic> json) => SongDto(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
  );

  final String id;
  final String title;
  final String artist;

  Song toDomain() => Song(id: id, title: title, artist: artist);
}

/// A complete chord sheet from `GET /api/songs/:id`.
class ChordSheetDto {
  const ChordSheetDto({
    required this.title,
    required this.artist,
    this.key,
    required this.lines,
  });

  factory ChordSheetDto.fromJson(Map<String, dynamic> json) => ChordSheetDto(
    title: json['title'] as String,
    artist: json['artist'] as String,
    key: json['key'] as String?,
    lines: (json['lines'] as List)
        .map((line) => _parseSheetLine(line as Map<String, dynamic>))
        .toList(),
  );

  final String title;
  final String artist;
  final String? key;
  final List<SheetLine> lines;

  ChordSheet toDomain() =>
      ChordSheet(title: title, artist: artist, key: key, lines: lines);
}

SheetLine _parseSheetLine(Map<String, dynamic> json) {
  return switch (json['type']) {
    'section' => SongSection(json['name'] as String),
    'lyric' => LyricLine(
      (json['words'] as List).map((word) {
        final w = word as Map<String, dynamic>;
        return WordChord(
          word: w['word'] as String,
          chord: w['chord'] as String?,
        );
      }).toList(),
    ),
    _ => throw FormatException('Unknown line type: ${json['type']}'),
  };
}