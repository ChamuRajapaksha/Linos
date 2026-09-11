import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/song_search_repository.dart';
import '../../../../domain/models/song.dart';

enum SongSearchState { idle, loading, results, empty, error }

class SongSearchViewModel extends ChangeNotifier {
  SongSearchViewModel({
    required SongSearchRepository repository,
    Duration debounce = const Duration(milliseconds: 300),
  })  : _repository = repository,
        _debounce = debounce;

  final SongSearchRepository _repository;
  final Duration _debounce;

  Timer? _debounceTimer;
  int _searchSeq = 0;

  String _query = '';
  String get query => _query;

  SongSearchState _state = SongSearchState.idle;
  SongSearchState get state => _state;

  List<Song> _results = const [];
  List<Song> get results => _results;

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
      _state = SongSearchState.idle;
      notifyListeners();
      return;
    }
    _query = q;
    _selectedSong = null;
    _debounceTimer = Timer(_debounce, () => unawaited(search(_query)));
  }

  Future<void> search(String value) async {
    final q = value.trim();
    if (q.isEmpty) {
      _query = '';
      _results = const [];
      _selectedSong = null;
      _errorMessage = null;
      _state = SongSearchState.idle;
      notifyListeners();
      return;
    }
    _query = q;
    _state = SongSearchState.loading;
    _errorMessage = null;
    notifyListeners();
    final seq = ++_searchSeq;
    try {
      final found = await _repository.search(q);
      if (seq == _searchSeq) {
        _results = found;
        _state =
            found.isEmpty ? SongSearchState.empty : SongSearchState.results;
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
    _state = SongSearchState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}