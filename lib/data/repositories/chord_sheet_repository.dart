import '../../domain/models/chord_sheet.dart';
import '../../domain/models/song.dart';

/// Interface for fetching the chord sheet for a given [Song].
///
/// Implementations can call a remote chords API or serve cached / mock data.
abstract class ChordSheetRepository {
  Future<ChordSheet> fetch(Song song);
}
