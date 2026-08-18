import 'frequency.dart';
import 'note.dart';

class PitchDetection {
  const PitchDetection({
    required this.frequency,
    required this.note,
    required this.centsOffset,
    required this.confidence,
    required this.rms,
    this.snrDb = 0.0,
  });

  final Frequency frequency;
  final Note note;
  final double centsOffset;
  final double confidence;
  final double rms;

  /// Peak-vs-noise-floor ratio in dB for the window that produced this reading.
  final double snrDb;

  @override
  bool operator ==(Object other) {
    return other is PitchDetection &&
        other.frequency == frequency &&
        other.note == note &&
        other.centsOffset == centsOffset &&
        other.confidence == confidence &&
        other.rms == rms &&
        other.snrDb == snrDb;
  }

  @override
  int get hashCode =>
      Object.hash(frequency, note, centsOffset, confidence, rms, snrDb);
}
