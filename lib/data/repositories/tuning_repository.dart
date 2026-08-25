import '../../domain/models/note.dart';
import '../../domain/models/tuning.dart';
import '../../domain/models/tuning_preset.dart';

class TuningRepository {
  const TuningRepository();

  List<TuningPreset> listPresets() => TuningPreset.all;

  TuningPreset? getPreset(String id) => TuningPreset.byId(id);

  Tuning tuningFor(String id, {double a4Reference = Note.a4Reference}) {
    final preset = TuningPreset.byId(id);
    if (preset == null) {
      throw ArgumentError.value(id, 'id', 'Unknown tuning preset');
    }
    return preset.tuningFor(a4Reference);
  }
}
