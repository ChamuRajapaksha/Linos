import '../../domain/models/chord_sheet.dart';
import '../../domain/models/song.dart';
import '../api/api_client.dart';
import '../api/api_models.dart';
import '../repositories/chord_sheet_repository.dart';

/// [ChordSheetRepository] backed by the Linos chords backend.
class ApiChordSheetRepository implements ChordSheetRepository {
  ApiChordSheetRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  @override
  Future<ChordSheet> fetch(Song song) async {
    final json = await _api.getJson('/api/songs/${song.id}');
    return ChordSheetDto.fromJson(json).toDomain();
  }
}