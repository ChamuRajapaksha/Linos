import '../domain/chord_sheet.dart';
import 'ug_store.dart';

class ChordSheetParseException implements Exception {
  ChordSheetParseException(this.message);

  final String message;

  @override
  String toString() => 'ChordSheetParseException: $message';
}

class UgChordParser {
  const UgChordParser();

  /// Parse a UG tab page HTML into a [ChordSheet].
  ChordSheet parse(String html) {
    final store = decodeStore(html);
    if (store == null) {
      throw ChordSheetParseException('Tab page has no store');
    }
    final tabView = _lookup(store, const ['store', 'page', 'data', 'tab_view']);
    if (tabView == null) {
      throw ChordSheetParseException('Tab page has no tab_view');
    }
    final headerMeta = tabView['headerMeta'];
    final title = headerMeta is Map<String, dynamic>
        ? _firstNonEmpty(headerMeta['name'], headerMeta['header_title'])
        : '';
    final artist = headerMeta is Map<String, dynamic> ? _readArtist(headerMeta) : '';
    final meta = tabView['meta'];
    final tonality = meta is Map<String, dynamic> ? meta['tonality'] : null;
    final String? key = tonality is String && tonality.isNotEmpty ? tonality : null;
    final wikiTab = tabView['wiki_tab'];
    final content = wikiTab is Map<String, dynamic> && wikiTab['content'] is String
        ? wikiTab['content'] as String
        : '';
    return ChordSheet(
      title: title,
      artist: artist,
      key: key,
      lines: parseChordPro(content),
    );
  }

  /// Parse raw ChordPro content (with section markers and chord tokens) into
  /// sheet lines. Public so it can be unit-tested directly.
  List<SongLine> parseChordPro(String content) {
    final out = <SongLine>[];
    var pending = <({String name, int col})>[];

    for (final rawLine in content.split('\n')) {
      var line = rawLine;
      if (line.startsWith('[tab]')) {
        line = line.substring('[tab]'.length);
      }
      if (line.endsWith('[/tab]')) {
        line = line.substring(0, line.length - '[/tab]'.length);
      }
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        _flushChordOnly(out, pending);
        pending = <({String name, int col})>[];
        continue;
      }
      if (trimmed.startsWith('{')) {
        _flushChordOnly(out, pending);
        pending = <({String name, int col})>[];
        continue;
      }
      final section = _sectionPattern.firstMatch(trimmed);
      if (section != null) {
        final name = section.group(1)!;
        if (name != 'tab' &&
            name != 'ch' &&
            !name.startsWith('/') &&
            !name.startsWith('ch[') &&
            !name.startsWith('tab[')) {
          _flushChordOnly(out, pending);
          pending = <({String name, int col})>[];
          out.add(SectionLine(name));
          continue;
        }
      }

      final chords = <({String name, int col})>[];
      final words = <({String token, int startCol})>[];
      _scan(line, chords, words);

      if (chords.isNotEmpty && words.isNotEmpty) {
        out.add(LyricLine(_attach(chords, words)));
        pending = <({String name, int col})>[];
      } else if (chords.isNotEmpty) {
        if (pending.isNotEmpty && !_sameChords(pending, chords)) {
          _flushChordOnly(out, pending);
        }
        pending = chords;
      } else {
        if (_gaugePattern.hasMatch(line) || (out.isEmpty && line.contains(' - '))) {
          continue;
        }
        if (pending.isNotEmpty) {
          out.add(LyricLine(_attach(pending, words)));
          pending = <({String name, int col})>[];
        } else {
          out.add(LyricLine([for (final w in words) WordChord(word: w.token)]));
        }
      }
    }

    _flushChordOnly(out, pending);
    return out;
  }

  static final RegExp _sectionPattern = RegExp(r'^\[([^\]]+)\]$');
  static final RegExp _gaugePattern = RegExp(
    r'^\s*[A-G][#b]?(?:m|maj|min|sus|dim|aug|add)?[A-Za-z0-9]*\s{2,}[\s0-9\-xX]+$',
  );
  static const Set<String> _spaces = {' ', '\t'};

  static Map<String, dynamic>? _lookup(Map<String, dynamic> root, List<String> path) {
    Object? node = root;
    for (final key in path) {
      if (node is! Map<String, dynamic>) return null;
      node = node[key];
    }
    return node is Map<String, dynamic> ? node : null;
  }

  static String _firstNonEmpty(Object? first, Object? second) {
    if (first is String && first.isNotEmpty) return first;
    if (second is String && second.isNotEmpty) return second;
    return '';
  }

  static String _readArtist(Map<String, dynamic> headerMeta) {
    final artists = headerMeta['artists'];
    if (artists is List<dynamic>) {
      final names = <String>[];
      for (final entry in artists) {
        if (entry is! Map<String, dynamic>) continue;
        final name = entry['name'];
        if (name is String && name.isNotEmpty) names.add(name);
      }
      if (names.isNotEmpty) return names.join(', ');
    }
    final single = headerMeta['artist_name'];
    if (single is String && single.isNotEmpty) return single;
    return '';
  }

  static List<WordChord> _attach(
    List<({String name, int col})> chords,
    List<({String token, int startCol})> words,
  ) {
    final out = <({String token, String? chord})>[
      for (final w in words) (token: w.token, chord: null),
    ];
    for (final c in chords) {
      var target = 0;
      for (var i = 0; i < words.length; i++) {
        if (words[i].startCol > c.col) break;
        target = i;
      }
      if (out[target].chord == null) {
        out[target] = (token: out[target].token, chord: c.name);
      }
    }
    return [for (final w in out) WordChord(word: w.token, chord: w.chord)];
  }

  static void _flushChordOnly(
    List<SongLine> out,
    List<({String name, int col})> chords,
  ) {
    if (chords.isEmpty) return;
    out.add(LyricLine([for (final c in chords) WordChord(word: '', chord: c.name)]));
  }

  static bool _sameChords(
    List<({String name, int col})> a,
    List<({String name, int col})> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].name != b[i].name || a[i].col != b[i].col) return false;
    }
    return true;
  }

  static void _scan(
    String line,
    List<({String name, int col})> chords,
    List<({String token, int startCol})> words,
  ) {
    final virtual = StringBuffer();
    String? run;
    var runStart = 0;
    void flushRun() {
      if (run != null) {
        words.add((token: run!, startCol: runStart));
        run = null;
      }
    }

    var i = 0;
    while (i < line.length) {
      if (line.startsWith('[ch]', i)) {
        flushRun();
        var end = line.indexOf('[/ch]', i + 4);
        var extra = 5;
        if (end == -1) {
          end = line.length;
          extra = 0;
        }
        final name = line.substring(i + 4, end);
        chords.add((name: name, col: virtual.length));
        virtual.write(name);
        i = end + extra;
      } else {
        final char = line[i];
        if (_spaces.contains(char)) {
          flushRun();
        } else if (run == null) {
          runStart = virtual.length;
          run = char;
        } else {
          run = run! + char;
        }
        virtual.write(char);
        i++;
      }
    }
    flushRun();
  }
}