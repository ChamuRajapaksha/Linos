import 'dart:math' as math;

import '../../domain/models/frequency.dart';
import '../models/detected_frequency.dart';
import 'pitch_detector.dart';

class FftPitchDetector implements PitchDetector {
  FftPitchDetector({this.config = const PitchDetectorConfig()}) {
    if (config.windowSize < 2) {
      throw ArgumentError('windowSize must be at least 2');
    }
    if (config.fftSize < config.windowSize) {
      throw ArgumentError('fftSize must be >= windowSize');
    }
    if (!_isPowerOfTwo(config.fftSize)) {
      throw ArgumentError('fftSize must be a power of two');
    }
    if (config.sampleRate <= 0) {
      throw ArgumentError('sampleRate must be positive');
    }
    if (config.minFrequency <= 0) {
      throw ArgumentError('minFrequency must be positive');
    }
    if (config.maxFrequency <= config.minFrequency) {
      throw ArgumentError('maxFrequency must be > minFrequency');
    }
    if (config.maxFrequency > config.sampleRate / 2) {
      throw ArgumentError('maxFrequency must be <= sampleRate / 2');
    }
    if (config.minConfidence < 0 || config.minConfidence > 1) {
      throw ArgumentError('minConfidence must be within [0, 1]');
    }
    if (config.minRms < 0 || config.minRms > 1) {
      throw ArgumentError('minRms must be within [0, 1]');
    }
  }

  final PitchDetectorConfig config;

  @override
  DetectedFrequency? detect(List<double> samples) {
    if (samples.length != config.windowSize) {
      throw ArgumentError(
        'samples.length (${samples.length}) must equal windowSize '
        '(${config.windowSize})',
      );
    }

    final windowed = List<double>.filled(config.windowSize, 0);
    var sumOfSquares = 0.0;
    for (var i = 0; i < config.windowSize; i++) {
      final window = 0.5 *
          (1 -
              math.cos(2 * math.pi * i / (config.windowSize - 1)));
      final value = samples[i] * window;
      windowed[i] = value;
      sumOfSquares += value * value;
    }

    final rms = math.sqrt(sumOfSquares / config.windowSize);
    if (rms < config.minRms) {
      return null;
    }

    final spectrum = magnitudeSpectrum(windowed, config.fftSize);
    final half = config.fftSize >> 1;

    final minBin = math.max(
      1,
      (config.minFrequency * config.fftSize / config.sampleRate).floor(),
    );
    final maxBin = math.min(
      half,
      (config.maxFrequency * config.fftSize / config.sampleRate).ceil(),
    );

    var peakBin = minBin;
    var peakMagnitude = spectrum[peakBin];
    var totalMagnitude = peakMagnitude;
    for (var bin = minBin + 1; bin <= maxBin; bin++) {
      totalMagnitude += spectrum[bin];
      if (spectrum[bin] > peakMagnitude) {
        peakMagnitude = spectrum[bin];
        peakBin = bin;
      }
    }

    if (totalMagnitude <= 0) {
      return null;
    }
    final confidence = peakMagnitude / totalMagnitude;
    if (confidence < config.minConfidence) {
      return null;
    }

    final refinedBin = _interpolatedBin(spectrum, peakBin, half);
    final frequency = refinedBin * config.sampleRate / config.fftSize;

    return DetectedFrequency(
      frequency: Frequency(value: frequency),
      confidence: confidence,
      rms: rms,
    );
  }

  static double _interpolatedBin(List<double> spectrum, int peakBin, int half) {
    if (peakBin <= 0 || peakBin >= half) {
      return peakBin.toDouble();
    }
    final left = math.log(spectrum[peakBin - 1]);
    final center = math.log(spectrum[peakBin]);
    final right = math.log(spectrum[peakBin + 1]);
    final denominator = left - 2 * center + right;
    if (!denominator.isFinite || denominator.abs() < 1e-12) {
      return peakBin.toDouble();
    }
    final delta = 0.5 * (left - right) / denominator;
    if (!delta.isFinite) {
      return peakBin.toDouble();
    }
    final refined = peakBin + delta;
    if (!refined.isFinite || refined < 0) {
      return peakBin.toDouble();
    }
    return refined;
  }

  static List<double> magnitudeSpectrum(List<double> samples, int fftSize) {
    if (!_isPowerOfTwo(fftSize)) {
      throw ArgumentError('fftSize must be a power of two');
    }
    if (samples.length > fftSize) {
      throw ArgumentError(
        'samples.length (${samples.length}) must not exceed fftSize '
        '($fftSize)',
      );
    }

    var re = List<double>.filled(fftSize, 0);
    final im = List<double>.filled(fftSize, 0);
    for (var i = 0; i < samples.length; i++) {
      re[i] = samples[i];
    }

    var j = 0;
    for (var i = 0; i < fftSize - 1; i++) {
      if (i < j) {
        final tmpRe = re[i];
        re[i] = re[j];
        re[j] = tmpRe;
        final tmpIm = im[i];
        im[i] = im[j];
        im[j] = tmpIm;
      }
      var m = fftSize >> 1;
      while (j >= m && m >= 1) {
        j -= m;
        m >>= 1;
      }
      j += m;
    }

    for (var size = 2; size <= fftSize; size <<= 1) {
      final half = size >> 1;
      final step = -2 * math.pi / size;
      for (var start = 0; start < fftSize; start += size) {
        for (var k = 0; k < half; k++) {
          final angle = step * k;
          final cosA = math.cos(angle);
          final sinA = math.sin(angle);
          final even = start + k;
          final odd = even + half;
          final oddRe = re[odd] * cosA - im[odd] * sinA;
          final oddIm = re[odd] * sinA + im[odd] * cosA;
          re[odd] = re[even] - oddRe;
          im[odd] = im[even] - oddIm;
          re[even] += oddRe;
          im[even] += oddIm;
        }
      }
    }

    final half = fftSize >> 1;
    final magnitudes = List<double>.filled(half + 1, 0);
    for (var i = 0; i <= half; i++) {
      magnitudes[i] = math.sqrt(re[i] * re[i] + im[i] * im[i]);
    }
    return magnitudes;
  }

  static bool _isPowerOfTwo(int value) {
    return value > 0 && (value & (value - 1)) == 0;
  }
}
