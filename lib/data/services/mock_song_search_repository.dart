import '../../domain/models/song.dart';
import '../repositories/song_search_repository.dart';

/// Mock implementation of [SongSearchRepository] backed by a local catalog.
///
/// Useful for UI development and integration tests before a real API exists.
class MockSongSearchRepository implements SongSearchRepository {
  /// Simulated network delay for search requests.
  static const Duration searchDelay = Duration(milliseconds: 250);

  static const List<Song> _catalog = [
    Song(id: 'wonderwall', title: 'Wonderwall', artist: 'Oasis'),
    Song(id: 'hallelujah', title: 'Hallelujah', artist: 'Leonard Cohen'),
    Song(
      id: 'knockin-on-heavens-door',
      title: "Knockin' on Heaven's Door",
      artist: 'Bob Dylan',
    ),
    Song(id: 'creep', title: 'Creep', artist: 'Radiohead'),
    Song(id: 'free-fallin', title: "Free Fallin'", artist: 'Tom Petty'),
    Song(id: 'hey-jude', title: 'Hey Jude', artist: 'The Beatles'),
    Song(id: 'let-it-be', title: 'Let It Be', artist: 'The Beatles'),
    Song(
      id: 'wish-you-were-here',
      title: 'Wish You Were Here',
      artist: 'Pink Floyd',
    ),
    Song(id: 'no-woman-no-cry', title: 'No Woman No Cry', artist: 'Bob Marley'),
    Song(id: 'radioactive', title: 'Radioactive', artist: 'Imagine Dragons'),
    Song(
      id: 'banana-pancakes',
      title: 'Banana Pancakes',
      artist: 'Jack Johnson',
    ),
    Song(
      id: 'country-roads',
      title: 'Take Me Home, Country Roads',
      artist: 'John Denver',
    ),
    Song(id: 'take-it-easy', title: 'Take It Easy', artist: 'Eagles'),
    Song(id: 'imagine', title: 'Imagine', artist: 'John Lennon'),
    Song(id: 'blackbird', title: 'Blackbird', artist: 'The Beatles'),
    Song(id: 'yesterday', title: 'Yesterday', artist: 'The Beatles'),
    Song(
      id: 'dust-in-the-wind',
      title: 'Dust in the Wind',
      artist: 'Kansas',
    ),
    Song(id: 'love-me-do', title: 'Love Me Do', artist: 'The Beatles'),
    Song(
      id: 'blowin-in-the-wind',
      title: "Blowin' in the Wind",
      artist: 'Bob Dylan',
    ),
    Song(id: 'riptide', title: 'Riptide', artist: 'Vance Joy'),
  ];

  /// The full song catalog.
  List<Song> get catalog => List.unmodifiable(_catalog);

  @override
  Future<List<Song>> search(String query) async {
    await Future.delayed(searchDelay);
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final lower = trimmed.toLowerCase();
    return _catalog.where((s) {
      return s.title.toLowerCase().contains(lower) ||
          s.artist.toLowerCase().contains(lower);
    }).toList();
  }
}
