import 'song.dart';

/// A paginated set of search results.
class SearchResults {
  const SearchResults({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  final List<Song> items;
  final int page;
  final bool hasMore;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! SearchResults) {
      return false;
    }
    return other.items == items && other.page == page && other.hasMore == hasMore;
  }

  @override
  int get hashCode => Object.hash(items, page, hasMore);
}