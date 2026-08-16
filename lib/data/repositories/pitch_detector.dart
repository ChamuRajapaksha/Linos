import '../models/detected_frequency.dart';

class PitchDetectorConfig {
  const PitchDetectorConfig({
    this.windowSize = 4096,
    this.fftSize = 32768,
    this.sampleRate = 44100,
    this.minFrequency = 70.0,
    this.maxFrequency = 1400.0,
    this.minConfidence = 0.05,
    this.minRms = 0.01,
  });

  final int windowSize;
  final int fftSize;
  final int sampleRate;
  final double minFrequency;
  final double maxFrequency;
  final double minConfidence;
  final double minRms;
}

abstract class PitchDetector {
  DetectedFrequency? detect(List<double> samples);
}
