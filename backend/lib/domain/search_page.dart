class SearchPage<T> {
  const SearchPage({required this.items, required this.page, required this.hasMore});

  final List<T> items;
  final int page;
  final bool hasMore;
}