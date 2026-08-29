import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/tuning_preset.dart';

abstract class CustomTuningStore {
  Future<List<TuningPreset>> loadCustomTunings();

  Future<void> saveAll(List<TuningPreset> tunings);
}

class SharedPreferencesCustomTuningStore implements CustomTuningStore {
  static const String _key = 'customTunings';

  @override
  Future<List<TuningPreset>> loadCustomTunings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    final stored =
        [for (final entry in decoded) _decodeTuning(entry as Map<String, dynamic>)];
    stored.sort((a, b) => a.name.compareTo(b.name));
    return stored;
  }

  @override
  Future<void> saveAll(List<TuningPreset> tunings) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode([for (final t in tunings) _encodeTuning(t)]);
    await prefs.setString(_key, encoded);
  }

  Map<String, dynamic> _encodeTuning(TuningPreset preset) {
    return {
      'id': preset.id,
      'name': preset.name,
      'notes': [
        for (final note in preset.notes)
          {'name': note.name, 'octave': note.octave},
      ],
    };
  }

  TuningPreset _decodeTuning(Map<String, dynamic> entry) {
    final id = entry['id'] as String;
    final name = entry['name'] as String;
    final notes = (entry['notes'] as List<dynamic>).map((noteEntry) {
      final map = noteEntry as Map<String, dynamic>;
      final noteName = map['name'] as String;
      final octave = map['octave'] as int;
      return TuningPreset.noteFor(noteName, octave);
    }).toList();
    return TuningPreset(id: id, name: name, notes: notes);
  }
}
