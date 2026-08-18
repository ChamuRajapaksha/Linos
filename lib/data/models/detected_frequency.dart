import '../../domain/models/frequency.dart';

class DetectedFrequency {
  const DetectedFrequency({
    required this.frequency,
    required this.confidence,
    required this.rms,
    this.snrDb = 0.0,
  });

  final Frequency frequency;
  final double confidence;
  final double rms;

  /// Peak-vs-noise-floor ratio in dB for the window that produced this reading.
  final double snrDb;

  @override
  bool operator ==(Object other) {
    return other is DetectedFrequency &&
        other.frequency == frequency &&
        other.confidence == confidence &&
        other.rms == rms &&
        other.snrDb == snrDb;
  }

  @override
  int get hashCode => Object.hash(frequency, confidence, rms, snrDb);
}