import 'dart:math';

import '../../domain/models/note.dart';
import '../../domain/models/tuning.dart';
import '../../domain/models/tuning_preset.dart';
import 'custom_tuning_store.dart';

class TuningRepository {
  TuningRepository({CustomTuningStore? customTuningStore})
      : _customTuningStore = customTuningStore;

  final CustomTuningStore? _customTuningStore;

  /// Custom tunings loaded from [CustomTuningStore], kept in memory as the
  /// sync source for [listPresets]/[getPreset].
  List<TuningPreset> _customTunings = [];

  static const String customIdPrefix = 'custom-';

  /// Loads persisted custom tunings. Safe to call on every [TuningPreset.all]
  /// consumers that need them (the ViewModel calls this after init).
  Future<void> refreshCustomTunings() async {
    final store = _customTuningStore;
    if (store == null) {
      _customTunings = const [];
      return;
    }
    try {
      _customTunings = await store.loadCustomTunings();
    } catch (_) {
      _customTunings = const [];
    }
  }

  List<TuningPreset> listPresets() => [...TuningPreset.all, ..._customTunings];

  TuningPreset? getPreset(String id) {
    final builtIn = TuningPreset.byId(id);
    if (builtIn != null) {
      return builtIn;
    }
    for (final custom in _customTunings) {
      if (custom.id == id) {
        return custom;
      }
    }
    return null;
  }

  Tuning tuningFor(String id, {double a4Reference = Note.a4Reference}) {
    final preset = getPreset(id);
    if (preset == null) {
      throw ArgumentError.value(id, 'id', 'Unknown tuning preset');
    }
    return preset.tuningFor(a4Reference);
  }

  bool isCustomId(String id) => id.startsWith(customIdPrefix);

  /// Persists a new custom tuning and adds it to the in-memory list.
  Future<TuningPreset> saveCustomTuning({
    required String name,
    required List<Note> notes,
  }) async {
    final id = '$customIdPrefix${_nextId()}';
    final preset = TuningPreset(id: id, name: name, notes: notes);
    _customTunings = [..._customTunings, preset]
      ..sort((a, b) => a.name.compareTo(b.name));
    await _persistCustomTunings();
    return preset;
  }

  /// Removes a custom tuning from memory and persistence.
  Future<void> deleteCustomTuning(String id) async {
    _customTunings = _customTunings.where((t) => t.id != id).toList();
    await _persistCustomTunings();
  }

  Future<void> _persistCustomTunings() async {
    final store = _customTuningStore;
    if (store == null) {
      return;
    }
    try {
      await store.saveAll(_customTunings);
    } catch (_) {
      // Persistence failure must not break the in-memory list.
    }
  }

  String _nextId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(1 << 16);
    return '$now-$random';
  }
}
