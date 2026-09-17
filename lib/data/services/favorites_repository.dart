import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/song.dart';

class FavoritesRepository extends ChangeNotifier {
  static const String _key = 'favoriteSongs';

  List<Song> _favorites = [];

  List<Song> get favorites => List.unmodifiable(_favorites);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      _favorites = [];
      notifyListeners();
      return;
    }
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    _favorites = [
      for (final entry in decoded)
        _decodeSong(entry as Map<String, dynamic>),
    ];
    notifyListeners();
  }

  bool contains(Song song) {
    return _favorites.any((s) => s.id == song.id);
  }

  Future<void> add(Song song) async {
    if (contains(song)) return;
    _favorites.add(song);
    notifyListeners();
    await _persist();
  }

  Future<void> remove(Song song) async {
    final index = _favorites.indexWhere((s) => s.id == song.id);
    if (index == -1) return;
    _favorites.removeAt(index);
    notifyListeners();
    await _persist();
  }

  Future<void> toggle(Song song) async {
    if (contains(song)) {
      await remove(song);
    } else {
      await add(song);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode([
      for (final song in _favorites) _encodeSong(song),
    ]);
    await prefs.setString(_key, encoded);
  }

  Map<String, dynamic> _encodeSong(Song song) {
    return {
      'id': song.id,
      'title': song.title,
      'artist': song.artist,
    };
  }

  Song _decodeSong(Map<String, dynamic> entry) {
    final id = entry['id'] as String;
    final title = entry['title'] as String;
    final artist = entry['artist'] as String;
    return Song(id: id, title: title, artist: artist);
  }
}
