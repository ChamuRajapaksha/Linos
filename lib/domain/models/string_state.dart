import 'note.dart';
import 'tuning_status.dart';

class StringState {
  const StringState({
    required this.targetNote,
    this.detectedFrequency,
    this.centsOffset,
    this.status = TuningStatus.inTune,
  });

  final Note targetNote;
  final double? detectedFrequency;
  final double? centsOffset;
  final TuningStatus status;

  static const Object _unset = Object();

  bool get hasReading => detectedFrequency != null;

  StringState copyWith({
    Note? targetNote,
    Object? detectedFrequency = _unset,
    Object? centsOffset = _unset,
    TuningStatus? status,
  }) {
    return StringState(
      targetNote: targetNote ?? this.targetNote,
      detectedFrequency: identical(detectedFrequency, _unset)
          ? this.detectedFrequency
          : detectedFrequency as double?,
      centsOffset: identical(centsOffset, _unset)
          ? this.centsOffset
          : centsOffset as double?,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StringState &&
        other.targetNote == targetNote &&
        other.detectedFrequency == detectedFrequency &&
        other.centsOffset == centsOffset &&
        other.status == status;
  }

  @override
  int get hashCode =>
      Object.hash(targetNote, detectedFrequency, centsOffset, status);
}
