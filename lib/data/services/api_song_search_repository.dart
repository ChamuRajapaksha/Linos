import '../../domain/models/song.dart';
import '../api/api_client.dart';
import '../api/api_models.dart';
import '../repositories/song_search_repository.dart';

/// [SongSearchRepository] backed by the Linos chords backend.
class ApiSongSearchRepository implements SongSearchRepository {
  ApiSongSearchRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  @override
  Future<List<Song>> search(String query) async {
    final json = await _api.getJson('/api/search', query: {'query': query});
    return SearchResponse.fromJson(json).items;
  }
}