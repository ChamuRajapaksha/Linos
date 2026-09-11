import '../../domain/models/chord_sheet.dart';
import '../../domain/models/song.dart';
import '../repositories/chord_sheet_repository.dart';

/// Mock implementation of [ChordSheetRepository] with bundled sample sheets.
///
/// Provides complete chord sheets for a handful of well-known songs so the UI
/// can be developed and tested without a real backend.
class MockChordSheetRepository implements ChordSheetRepository {
  /// Simulated network delay for fetch requests.
  static const Duration fetchDelay = Duration(milliseconds: 200);

  static const Map<String, ChordSheet> _sheets = {
    'wonderwall': _wonderwall,
    'hallelujah': _hallelujah,
    'knockin-on-heavens-door': _knockinOnHeavensDoor,
    'free-fallin': _freeFallin,
  };

  /// Song ids that have a bundled chord sheet.
  Set<String> get bundledSongIds => _sheets.keys.toSet();

  @override
  Future<ChordSheet> fetch(Song song) async {
    await Future.delayed(fetchDelay);
    final sheet = _sheets[song.id];
    if (sheet == null) {
      throw StateError('No sheet bundled for ${song.id}');
    }
    return sheet;
  }
}

// ---------------------------------------------------------------------------
// Wonderwall – Oasis  (Key: F#m)
// Chords: F#m, A, E, Bm, D
// ---------------------------------------------------------------------------

const _wonderwall = ChordSheet(
  title: 'Wonderwall',
  artist: 'Oasis',
  key: 'F#m',
  lines: [
    // Verse 1 ---------------------------------------------------------------
    SongSection('[Verse 1]'),
    LyricLine([
      WordChord(word: 'Today', chord: 'F#m'),
      WordChord(word: 'is'),
      WordChord(word: 'gonna'),
      WordChord(word: 'be'),
      WordChord(word: 'the'),
      WordChord(word: 'day'),
    ]),
    LyricLine([
      WordChord(word: "That"),
      WordChord(word: "they're"),
      WordChord(word: 'gonna'),
      WordChord(word: 'throw', chord: 'A'),
      WordChord(word: 'it'),
      WordChord(word: 'back'),
      WordChord(word: 'to'),
      WordChord(word: 'you'),
    ]),
    LyricLine([
      WordChord(word: 'By', chord: 'E'),
      WordChord(word: 'now'),
      WordChord(word: 'you'),
      WordChord(word: "should've"),
      WordChord(word: 'somehow'),
    ]),
    LyricLine([
      WordChord(word: 'Realized', chord: 'Bm'),
      WordChord(word: 'what'),
      WordChord(word: 'you'),
      WordChord(word: 'gotta'),
      WordChord(word: 'do'),
    ]),
    LyricLine([
      WordChord(word: 'I'),
      WordChord(word: "don't"),
      WordChord(word: 'believe'),
      WordChord(word: 'that', chord: 'D'),
      WordChord(word: 'anybody'),
    ]),
    LyricLine([
      WordChord(word: 'Feels', chord: 'A'),
      WordChord(word: 'the'),
      WordChord(word: 'way'),
      WordChord(word: 'I'),
      WordChord(word: 'do'),
    ]),
    LyricLine([
      WordChord(word: 'About', chord: 'E'),
      WordChord(word: 'you'),
      WordChord(word: 'now'),
    ]),
    // Verse 2 ---------------------------------------------------------------
    SongSection('[Verse 2]'),
    LyricLine([
      WordChord(word: 'Back', chord: 'F#m'),
      WordChord(word: 'on'),
      WordChord(word: 'the'),
      WordChord(word: 'street'),
      WordChord(word: 'where'),
    ]),
    LyricLine([
      WordChord(word: 'You'),
      WordChord(word: 'were'),
      WordChord(word: 'gonna'),
      WordChord(word: 'be', chord: 'A'),
      WordChord(word: 'the'),
      WordChord(word: 'one'),
    ]),
    LyricLine([
      WordChord(word: 'That'),
      WordChord(word: 'saves'),
      WordChord(word: 'me', chord: 'E'),
    ]),
    LyricLine([
      WordChord(word: 'After', chord: 'Bm'),
      WordChord(word: 'all'),
      WordChord(word: "you're", chord: 'D'),
      WordChord(word: 'my'),
      WordChord(word: 'wonderwall'),
    ]),
    // Chorus ----------------------------------------------------------------
    SongSection('[Chorus]'),
    LyricLine([
      WordChord(word: 'By', chord: 'F#m'),
      WordChord(word: 'now'),
      WordChord(word: 'you'),
      WordChord(word: "should've"),
      WordChord(word: 'somehow', chord: 'A'),
    ]),
    LyricLine([
      WordChord(word: 'Realized', chord: 'E'),
      WordChord(word: 'what'),
      WordChord(word: 'you'),
      WordChord(word: 'gotta'),
      WordChord(word: 'do'),
    ]),
    LyricLine([
      WordChord(word: 'I'),
      WordChord(word: "don't"),
      WordChord(word: 'believe', chord: 'Bm'),
      WordChord(word: 'that'),
      WordChord(word: 'anybody'),
    ]),
    LyricLine([
      WordChord(word: 'Feels'),
      WordChord(word: 'the'),
      WordChord(word: 'way', chord: 'D'),
      WordChord(word: 'I'),
      WordChord(word: 'do'),
    ]),
    LyricLine([
      WordChord(word: 'About', chord: 'A'),
      WordChord(word: 'you'),
      WordChord(word: 'now', chord: 'E'),
    ]),
  ],
);

// ---------------------------------------------------------------------------
// Hallelujah – Leonard Cohen  (Key: C)
// Chords: C, Am, F, G, Em
// ---------------------------------------------------------------------------

const _hallelujah = ChordSheet(
  title: 'Hallelujah',
  artist: 'Leonard Cohen',
  key: 'C',
  lines: [
    // Verse 1 ---------------------------------------------------------------
    SongSection('[Verse 1]'),
    LyricLine([
      WordChord(word: "I've", chord: 'C'),
      WordChord(word: 'heard'),
      WordChord(word: 'there'),
      WordChord(word: 'was'),
      WordChord(word: 'a'),
      WordChord(word: 'secret'),
      WordChord(word: 'chord'),
    ]),
    LyricLine([
      WordChord(word: 'That', chord: 'Am'),
      WordChord(word: 'David'),
      WordChord(word: 'played'),
      WordChord(word: 'and'),
      WordChord(word: 'it'),
      WordChord(word: 'pleased'),
      WordChord(word: 'the'),
      WordChord(word: 'Lord'),
    ]),
    LyricLine([
      WordChord(word: 'But', chord: 'F'),
      WordChord(word: 'you'),
      WordChord(word: "don't"),
      WordChord(word: 'really'),
      WordChord(word: 'care'),
      WordChord(word: 'for'),
      WordChord(word: 'music'),
      WordChord(word: 'do'),
      WordChord(word: 'you'),
    ]),
    LyricLine([
      WordChord(word: 'It', chord: 'G'),
      WordChord(word: 'goes'),
      WordChord(word: 'like'),
      WordChord(word: 'this', chord: 'C'),
      WordChord(word: 'the'),
      WordChord(word: 'fourth'),
      WordChord(word: 'the', chord: 'Am'),
      WordChord(word: 'fifth'),
    ]),
    LyricLine([
      WordChord(word: 'The', chord: 'F'),
      WordChord(word: 'minor'),
      WordChord(word: 'fall'),
      WordChord(word: 'the', chord: 'G'),
      WordChord(word: 'major'),
      WordChord(word: 'lift'),
    ]),
    LyricLine([
      WordChord(word: 'The', chord: 'C'),
      WordChord(word: 'baffled'),
      WordChord(word: 'king'),
      WordChord(word: 'composing', chord: 'Am'),
      WordChord(word: 'Hallelujah'),
    ]),
    // Verse 2 ---------------------------------------------------------------
    SongSection('[Verse 2]'),
    LyricLine([
      WordChord(word: 'Your', chord: 'C'),
      WordChord(word: 'faith'),
      WordChord(word: 'was'),
      WordChord(word: 'strong'),
      WordChord(word: 'but'),
      WordChord(word: 'you'),
      WordChord(word: 'needed'),
      WordChord(word: 'proof'),
    ]),
    LyricLine([
      WordChord(word: 'You', chord: 'Am'),
      WordChord(word: 'saw'),
      WordChord(word: 'her'),
      WordChord(word: 'bathing'),
      WordChord(word: 'on'),
      WordChord(word: 'the'),
      WordChord(word: 'roof'),
    ]),
    LyricLine([
      WordChord(word: 'Her', chord: 'F'),
      WordChord(word: 'beauty'),
      WordChord(word: 'and'),
      WordChord(word: 'the'),
      WordChord(word: 'moonlight'),
      WordChord(word: 'overthrew'),
      WordChord(word: 'you'),
    ]),
    LyricLine([
      WordChord(word: 'She', chord: 'G'),
      WordChord(word: 'tied'),
      WordChord(word: 'you'),
      WordChord(word: 'to'),
      WordChord(word: 'a'),
      WordChord(word: 'kitchen', chord: 'Em'),
      WordChord(word: 'chair'),
    ]),
    LyricLine([
      WordChord(word: 'She', chord: 'F'),
      WordChord(word: 'broke'),
      WordChord(word: 'your'),
      WordChord(word: 'throne'),
      WordChord(word: 'and', chord: 'G'),
      WordChord(word: 'she'),
      WordChord(word: 'cut'),
      WordChord(word: 'your'),
      WordChord(word: 'hair'),
    ]),
    LyricLine([
      WordChord(word: 'And', chord: 'C'),
      WordChord(word: 'from'),
      WordChord(word: 'your'),
      WordChord(word: 'lips', chord: 'Am'),
      WordChord(word: 'she'),
      WordChord(word: 'drew'),
      WordChord(word: 'the', chord: 'F'),
      WordChord(word: 'Hallelujah'),
    ]),
    // Chorus ----------------------------------------------------------------
    SongSection('[Chorus]'),
    LyricLine([
      WordChord(word: 'Hallelujah', chord: 'C'),
      WordChord(word: 'Hallelujah', chord: 'Am'),
    ]),
    LyricLine([
      WordChord(word: 'Hallelujah', chord: 'F'),
      WordChord(word: 'Hallelujah', chord: 'G'),
    ]),
    LyricLine([
      WordChord(word: 'Hallelujah', chord: 'C'),
      WordChord(word: 'Hallelujah', chord: 'Am'),
    ]),
    LyricLine([
      WordChord(word: 'Hallelujah', chord: 'F'),
      WordChord(word: 'Hallelujah', chord: 'G'),
    ]),
  ],
);

// ---------------------------------------------------------------------------
// Knockin' on Heaven's Door – Bob Dylan  (Key: G)
// Chords: G, D, Am, C
// ---------------------------------------------------------------------------

const _knockinOnHeavensDoor = ChordSheet(
  title: "Knockin' on Heaven's Door",
  artist: 'Bob Dylan',
  key: 'G',
  lines: [
    // Verse 1 ---------------------------------------------------------------
    SongSection('[Verse 1]'),
    LyricLine([
      WordChord(word: 'Mama', chord: 'G'),
      WordChord(word: 'take'),
      WordChord(word: 'this'),
      WordChord(word: 'badge', chord: 'D'),
      WordChord(word: 'off'),
      WordChord(word: 'of'),
      WordChord(word: 'me'),
    ]),
    LyricLine([
      WordChord(word: 'I', chord: 'Am'),
      WordChord(word: "can't"),
      WordChord(word: 'use'),
      WordChord(word: 'it'),
      WordChord(word: 'anymore'),
    ]),
    LyricLine([
      WordChord(word: "It's", chord: 'C'),
      WordChord(word: 'getting'),
      WordChord(word: 'dark'),
      WordChord(word: 'too', chord: 'G'),
      WordChord(word: 'dark'),
      WordChord(word: 'to'),
      WordChord(word: 'see'),
    ]),
    LyricLine([
      WordChord(word: 'Feels', chord: 'D'),
      WordChord(word: 'like'),
      WordChord(word: "I'm"),
      WordChord(word: "knockin'", chord: 'Am'),
      WordChord(word: 'on'),
      WordChord(word: "heaven's", chord: 'C'),
      WordChord(word: 'door'),
    ]),
    // Verse 2 ---------------------------------------------------------------
    SongSection('[Verse 2]'),
    LyricLine([
      WordChord(word: 'Mama', chord: 'G'),
      WordChord(word: 'put'),
      WordChord(word: 'my'),
      WordChord(word: 'guns', chord: 'D'),
      WordChord(word: 'in'),
      WordChord(word: 'the'),
      WordChord(word: 'ground'),
    ]),
    LyricLine([
      WordChord(word: 'I', chord: 'Am'),
      WordChord(word: "can't"),
      WordChord(word: 'shoot'),
      WordChord(word: 'them'),
      WordChord(word: 'anymore'),
    ]),
    LyricLine([
      WordChord(word: 'That', chord: 'C'),
      WordChord(word: 'long'),
      WordChord(word: 'black'),
      WordChord(word: 'cloud', chord: 'G'),
      WordChord(word: 'is'),
      WordChord(word: 'coming'),
      WordChord(word: 'down'),
    ]),
    LyricLine([
      WordChord(word: 'Feels', chord: 'D'),
      WordChord(word: 'like'),
      WordChord(word: "I'm"),
      WordChord(word: "knockin'", chord: 'Am'),
      WordChord(word: 'on'),
      WordChord(word: "heaven's", chord: 'C'),
      WordChord(word: 'door'),
    ]),
    // Chorus ----------------------------------------------------------------
    SongSection('[Chorus]'),
    LyricLine([
      WordChord(word: "Knock-knock-knockin'", chord: 'G'),
      WordChord(word: "on", chord: 'D'),
      WordChord(word: "heaven's", chord: 'Am'),
      WordChord(word: 'door'),
    ]),
    LyricLine([
      WordChord(word: "Knock-knock-knockin'", chord: 'C'),
      WordChord(word: "on", chord: 'G'),
      WordChord(word: "heaven's", chord: 'D'),
      WordChord(word: 'door'),
    ]),
    LyricLine([
      WordChord(word: "Knock-knock-knockin'", chord: 'Am'),
      WordChord(word: "on", chord: 'C'),
      WordChord(word: "heaven's", chord: 'G'),
      WordChord(word: 'door'),
    ]),
    LyricLine([
      WordChord(word: "Knock-knock-knockin'", chord: 'D'),
      WordChord(word: "on", chord: 'Am'),
      WordChord(word: "heaven's", chord: 'C'),
      WordChord(word: 'door'),
    ]),
  ],
);

// ---------------------------------------------------------------------------
// Free Fallin' – Tom Petty  (Key: F)
// Chords: F, Bb, C, Am, Dm
// ---------------------------------------------------------------------------

const _freeFallin = ChordSheet(
  title: "Free Fallin'",
  artist: 'Tom Petty',
  key: 'F',
  lines: [
    // Verse 1 ---------------------------------------------------------------
    SongSection('[Verse 1]'),
    LyricLine([
      WordChord(word: "She's", chord: 'F'),
      WordChord(word: 'a'),
      WordChord(word: 'good'),
      WordChord(word: 'girl'),
      WordChord(word: 'loves', chord: 'Bb'),
      WordChord(word: 'her'),
      WordChord(word: 'mama'),
    ]),
    LyricLine([
      WordChord(word: 'Loves', chord: 'Am'),
      WordChord(word: 'Jesus'),
      WordChord(word: 'and'),
      WordChord(word: 'America'),
      WordChord(word: 'too'),
    ]),
    LyricLine([
      WordChord(word: "She's", chord: 'F'),
      WordChord(word: 'a'),
      WordChord(word: 'good'),
      WordChord(word: 'girl'),
      WordChord(word: 'crazy', chord: 'Dm'),
      WordChord(word: 'about'),
      WordChord(word: 'Elvis'),
    ]),
    LyricLine([
      WordChord(word: 'Loves', chord: 'C'),
      WordChord(word: 'horses'),
      WordChord(word: 'and'),
      WordChord(word: 'her'),
      WordChord(word: 'boyfriend'),
      WordChord(word: 'too'),
    ]),
    // Verse 2 ---------------------------------------------------------------
    SongSection('[Verse 2]'),
    LyricLine([
      WordChord(word: 'And', chord: 'F'),
      WordChord(word: 'all'),
      WordChord(word: 'the'),
      WordChord(word: 'vampires', chord: 'Bb'),
      WordChord(word: "walkin'"),
      WordChord(word: 'through'),
      WordChord(word: 'the'),
      WordChord(word: 'valley'),
    ]),
    LyricLine([
      WordChord(word: 'Move', chord: 'Am'),
      WordChord(word: 'west'),
      WordChord(word: 'down'),
      WordChord(word: 'Ventura'),
      WordChord(word: 'Boulevard'),
    ]),
    LyricLine([
      WordChord(word: 'And', chord: 'F'),
      WordChord(word: 'all'),
      WordChord(word: 'the'),
      WordChord(word: 'bad', chord: 'Dm'),
      WordChord(word: 'boys'),
      WordChord(word: 'are'),
      WordChord(word: 'standing'),
      WordChord(word: 'in'),
      WordChord(word: 'the'),
      WordChord(word: 'shadows'),
    ]),
    LyricLine([
      WordChord(word: 'And', chord: 'C'),
      WordChord(word: 'the'),
      WordChord(word: 'good'),
      WordChord(word: 'girls'),
      WordChord(word: 'are'),
      WordChord(word: 'home'),
      WordChord(word: 'with', chord: 'Bb'),
      WordChord(word: 'broken'),
      WordChord(word: 'hearts'),
    ]),
    // Chorus ----------------------------------------------------------------
    SongSection('[Chorus]'),
    LyricLine([
      WordChord(word: 'Free', chord: 'F'),
      WordChord(word: "fallin'", chord: 'Bb'),
    ]),
    LyricLine([
      WordChord(word: '(Free', chord: 'F'),
      WordChord(word: "fallin')", chord: 'Bb'),
    ]),
    LyricLine([
      WordChord(word: 'Free', chord: 'C'),
      WordChord(word: "fallin'", chord: 'F'),
    ]),
    LyricLine([
      WordChord(word: '(Free', chord: 'C'),
      WordChord(word: "fallin')", chord: 'F'),
    ]),
  ],
);
