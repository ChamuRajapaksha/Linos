import 'frequency.dart';
import 'note.dart';

class PitchDetection {
  const PitchDetection({
    required this.frequency,
    required this.note,
    required this.centsOffset,
    required this.confidence,
    required this.rms,
  });

  final Frequency frequency;
  final Note note;
  final double centsOffset;
  final double confidence;
  final double rms;

  @override
  bool operator ==(Object other) {
    return other is PitchDetection &&
        other.frequency == frequency &&
        other.note == note &&
        other.centsOffset == centsOffset &&
        other.confidence == confidence &&
        other.rms == rms;
  }

  @override
  int get hashCode =>
      Object.hash(frequency, note, centsOffset, confidence, rms);
}
