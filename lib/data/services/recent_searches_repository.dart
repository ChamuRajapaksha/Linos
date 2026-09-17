import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentSearchesRepository extends ChangeNotifier {
  static const String _key = 'recentSearches';
  static const int maxEntries = 10;

  List<String> _items = [];

  List<String> get recent => List.unmodifiable(_items);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _items = prefs.getStringList(_key) ?? [];
    notifyListeners();
  }

  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _items.remove(trimmed);
    _items.insert(0, trimmed);

    if (_items.length > maxEntries) {
      _items = _items.sublist(0, maxEntries);
    }

    notifyListeners();
    await _persist();
  }

  Future<void> remove(String query) async {
    final removed = _items.remove(query);
    if (!removed) return;

    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _items = [];
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _items);
  }
}
