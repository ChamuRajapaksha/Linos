import '../../domain/models/frequency.dart';

class DetectedFrequency {
  const DetectedFrequency({
    required this.frequency,
    required this.confidence,
    required this.rms,
  });

  final Frequency frequency;
  final double confidence;
  final double rms;

  @override
  bool operator ==(Object other) {
    return other is DetectedFrequency &&
        other.frequency == frequency &&
        other.confidence == confidence &&
        other.rms == rms;
  }

  @override
  int get hashCode => Object.hash(frequency, confidence, rms);
}
