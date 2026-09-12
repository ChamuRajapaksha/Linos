import '../domain/search_page.dart';
import '../domain/song.dart';
import 'ug_http_client.dart';
import 'ug_store.dart';

class UgSongResult {
  const UgSongResult({required this.song, required this.tabUrl});

  final Song song;
  final String tabUrl;
}

class UgSearchClient {
  UgSearchClient(this._httpClient);

  final UgHttpClient _httpClient;

  static const String _searchUrl =
      'https://www.ultimate-guitar.com/search.php?search_type=title';

  Future<SearchPage<UgSongResult>> search(String query, {int page = 1}) async {
    final url =
        '$_searchUrl&page=$page&type=300&value=${Uri.encodeQueryComponent(query)}';
    final html = await _httpClient.get(url);
    final store = decodeStore(html);
    if (store == null) {
      throw const FormatException('UG search response did not contain a store');
    }
    final data = store['store']?['page']?['data'];
    if (data is! Map<String, dynamic>) {
      return SearchPage(items: const [], page: page, hasMore: false);
    }
    final items = _parseResults(data['results']);
    final hasMore = _hasMore(data['pagination']);
    return SearchPage(items: items, page: page, hasMore: hasMore);
  }

  static List<UgSongResult> _parseResults(Object? results) {
    if (results is! List) return const <UgSongResult>[];
    final items = <UgSongResult>[];
    for (final entry in results) {
      if (entry is! Map) continue;
      final id = entry['id'];
      final title = entry['song_name'];
      final artist = entry['artist_name'];
      final tabUrl = entry['tab_url'];
      if (id == null || title is! String || artist is! String) continue;
      if (tabUrl is! String || tabUrl.isEmpty) continue;
      items.add(UgSongResult(
        song: Song(id: id.toString(), title: title, artist: artist),
        tabUrl: tabUrl,
      ));
    }
    return items;
  }

  static bool _hasMore(Object? pagination) {
    if (pagination is! Map) return false;
    final current = pagination['current'];
    final total = pagination['total'];
    if (current is! num || total is! num) return false;
    return current < total;
  }
}