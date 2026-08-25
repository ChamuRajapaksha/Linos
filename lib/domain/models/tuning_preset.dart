import 'note.dart';
import 'tuning.dart';

class TuningPreset {
  const TuningPreset({
    required this.id,
    required this.name,
    required this.notes,
  });

  final String id;
  final String name;
  final List<Note> notes;

  static final TuningPreset standard = TuningPreset(
    id: 'standard',
    name: 'Standard',
    notes: Tuning.standard.notes,
  );

  static final List<TuningPreset> all = [
    standard,
  ];

  static TuningPreset? byId(String id) {
    for (final preset in all) {
      if (preset.id == id) {
        return preset;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! TuningPreset) {
      return false;
    }
    if (other.id != id || other.name != name || other.notes.length != notes.length) {
      return false;
    }
    for (var i = 0; i < notes.length; i++) {
      if (other.notes[i] != notes[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(notes));
}
