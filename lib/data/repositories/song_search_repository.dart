import '../../domain/models/song.dart';

/// Interface for searching songs by query.
///
/// Implementations can wrap a real chords API (e.g. Ultimate Guitar, Chords.cc)
/// or return mock data for testing.
abstract class SongSearchRepository {
  Future<List<Song>> search(String query);
}
