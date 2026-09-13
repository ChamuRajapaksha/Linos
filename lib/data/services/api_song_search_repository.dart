import '../../domain/models/search_results.dart';
import '../api/api_client.dart';
import '../api/api_models.dart';
import '../repositories/song_search_repository.dart';

/// [SongSearchRepository] backed by the Linos chords backend.
class ApiSongSearchRepository implements SongSearchRepository {
  ApiSongSearchRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  @override
  Future<SearchResults> search(String query, {int page = 1}) async {
    final json = await _api.getJson('/api/search', query: {'query': query, 'page': '$page'});
    final resp = SearchResponse.fromJson(json);
    return SearchResults(items: resp.items, page: resp.page, hasMore: resp.hasMore);
  }
}