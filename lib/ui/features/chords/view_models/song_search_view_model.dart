import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/song_search_repository.dart';
import '../../../../data/services/favorites_repository.dart';
import '../../../../data/services/recent_searches_repository.dart';
import '../../../../domain/models/song.dart';

enum SongSearchState { idle, loading, results, empty, error }

class SongSearchViewModel extends ChangeNotifier {
  SongSearchViewModel({
    required SongSearchRepository repository,
    Duration debounce = const Duration(milliseconds: 300),
    FavoritesRepository? favorites,
    RecentSearchesRepository? recents,
  })  : _repository = repository,
        _debounce = debounce,
        _favorites = favorites ?? FavoritesRepository(),
        _recents = recents ?? RecentSearchesRepository() {
    _favorites.addListener(_onRepositoryChanged);
    _recents.addListener(_onRepositoryChanged);
    unawaited(_favorites.load());
    unawaited(_recents.load());
  }

  final SongSearchRepository _repository;
  final Duration _debounce;
  final FavoritesRepository _favorites;
  final RecentSearchesRepository _recents;

  void _onRepositoryChanged() => notifyListeners();

  Timer? _debounceTimer;
  int _searchSeq = 0;

  String _query = '';
  String get query => _query;

  SongSearchState _state = SongSearchState.idle;
  SongSearchState get state => _state;

  List<Song> _results = const [];
  List<Song> get results => _results;

  int _page = 1;
  int get page => _page;

  bool _hasMore = false;
  bool get hasMore => _hasMore;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Song? _selectedSong;
  Song? get selectedSong => _selectedSong;

  void onQueryChanged(String value) {
    _debounceTimer?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      _debounceTimer = null;
      _query = '';
      _results = const [];
      _selectedSong = null;
      _errorMessage = null;
      _page = 1;
      _hasMore = false;
      _isLoadingMore = false;
      _state = SongSearchState.idle;
      notifyListeners();
      return;
    }
    _query = q;
    _selectedSong = null;
    _debounceTimer = Timer(_debounce, () {
      unawaited(recordSearch(_query));
      unawaited(search(_query));
    });
  }

  bool isFavorite(Song song) => _favorites.contains(song);

  List<Song> get favorites => _favorites.favorites;

  List<String> get recents => _recents.recent;

  Future<void> toggleFavorite(Song song) async {
    await _favorites.toggle(song);
  }

  Future<void> recordSearch(String query) async {
    await _recents.add(query);
  }

  Future<void> clearRecents() async {
    await _recents.clear();
  }

  Future<void> removeRecent(String query) async {
    await _recents.remove(query);
  }

  Future<void> search(String value) async {
    final q = value.trim();
    if (q.isEmpty) {
      _query = '';
      _results = const [];
      _selectedSong = null;
      _errorMessage = null;
      _page = 1;
      _hasMore = false;
      _isLoadingMore = false;
      _state = SongSearchState.idle;
      notifyListeners();
      return;
    }
    _query = q;
    _page = 1;
    _hasMore = false;
    _isLoadingMore = false;
    _state = SongSearchState.loading;
    _errorMessage = null;
    notifyListeners();
    final seq = ++_searchSeq;
    try {
      final found = await _repository.search(q);
      if (seq == _searchSeq) {
        _results = found.items;
        _page = found.page;
        _hasMore = found.hasMore;
        _state = found.items.isEmpty
            ? SongSearchState.empty
            : SongSearchState.results;
      }
    } catch (e) {
      if (seq == _searchSeq) {
        _state = SongSearchState.error;
        _errorMessage = e.toString();
      }
    }
    if (seq == _searchSeq) {
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _state != SongSearchState.results) {
      return;
    }
    _isLoadingMore = true;
    notifyListeners();
    final seq = _searchSeq;
    final nextPage = _page + 1;
    try {
      final found = await _repository.search(_query, page: nextPage);
      if (seq == _searchSeq) {
        _results = [..._results, ...found.items];
        _page = found.page;
        _hasMore = found.hasMore;
      }
    } catch (_) {
      // Keep current results; the user can retry by scrolling again.
    } finally {
      if (seq == _searchSeq) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void selectSong(Song song) {
    _selectedSong = song;
    notifyListeners();
  }

  void clear() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _query = '';
    _results = const [];
    _selectedSong = null;
    _errorMessage = null;
    _page = 1;
    _hasMore = false;
    _isLoadingMore = false;
    _state = SongSearchState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _favorites.removeListener(_onRepositoryChanged);
    _recents.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}