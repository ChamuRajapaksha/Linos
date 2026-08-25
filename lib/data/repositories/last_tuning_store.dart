import 'package:shared_preferences/shared_preferences.dart';

abstract class LastTuningStore {
  Future<String?> getLastTuningId();

  Future<void> setLastTuningId(String id);
}

class SharedPreferencesLastTuningStore implements LastTuningStore {
  static const String _key = 'lastTuningId';

  @override
  Future<String?> getLastTuningId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> setLastTuningId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id);
  }
}
