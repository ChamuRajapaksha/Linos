import '../models/detected_frequency.dart';

class PitchDetectorConfig {
  const PitchDetectorConfig({
    this.windowSize = 4096,
    // FFT size was 32768 (zero-padded). Empirically verified 4096 with
    // log-parabolic interpolation: pure-sine accuracy <= 0.18 Hz across
    // phases (tolerance 1.0 Hz), 8x cheaper than 32768.
    this.fftSize = 4096,
    this.sampleRate = 44100,
    this.minFrequency = 70.0,
    this.maxFrequency = 1400.0,
    this.minConfidence = 0.20,
    this.minRms = 0.02,
    this.minSnrDb = 6.0,
    this.useHps = false,
  });

  final int windowSize;
  final int fftSize;
  final int sampleRate;
  final double minFrequency;
  final double maxFrequency;
  final double minConfidence;
  final double minRms;
  final double minSnrDb;
  final bool useHps;
}

abstract class PitchDetector {
  DetectedFrequency? detect(List<double> samples);
}