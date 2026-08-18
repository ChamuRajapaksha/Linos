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
    if (config.minSnrDb < 0) {
      throw ArgumentError('minSnrDb must be non-negative');
    }

    _windowed = List<double>.filled(config.windowSize, 0);
    _re = List<double>.filled(config.fftSize, 0);
    _im = List<double>.filled(config.fftSize, 0);
    _magnitudes = List<double>.filled((config.fftSize >> 1) + 1, 0);
  }

  final PitchDetectorConfig config;

  // HPS multiplies the spectrum downsampled by factors 1..3, i.e. H^3.
  // Order 4 was tried first: at the 4096-point default FFT a low detuned
  // string's 4th partial can sit ~2 bins off its integer bin, which lets
  // the octave-up (even-harmonic) candidate win. Order 3 stays aligned.
  static const int hpsOrders = 3;

  late final List<double> _windowed;
  late final List<double> _re;
  late final List<double> _im;
  late final List<double> _magnitudes;

  @override
  DetectedFrequency? detect(List<double> samples) {
    if (samples.length != config.windowSize) {
      throw ArgumentError(
        'samples.length (${samples.length}) must equal windowSize '
        '(${config.windowSize})',
      );
    }

    var sumOfSquares = 0.0;
    for (var i = 0; i < config.windowSize; i++) {
      final window = 0.5 *
          (1 - math.cos(2 * math.pi * i / (config.windowSize - 1)));
      final value = samples[i] * window;
      _windowed[i] = value;
      sumOfSquares += value * value;
    }

    final rms = math.sqrt(sumOfSquares / config.windowSize);
    if (rms < config.minRms) {
      return null;
    }

    _computeMagnitudes();

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
    if (config.useHps) {
      final hpsMaxBin = math.min(maxBin, half ~/ hpsOrders);
      if (hpsMaxBin < minBin) {
        return null;
      }
      var bestScore = _hpsScore(minBin);
      for (var bin = minBin + 1; bin <= hpsMaxBin; bin++) {
        final score = _hpsScore(bin);
        if (score > bestScore) {
          bestScore = score;
          peakBin = bin;
        }
      }
    } else {
      var peakMagnitude = _magnitudes[peakBin];
      for (var bin = minBin + 1; bin <= maxBin; bin++) {
        if (_magnitudes[bin] > peakMagnitude) {
          peakMagnitude = _magnitudes[bin];
          peakBin = bin;
        }
      }
    }

    final peakMagnitude = _magnitudes[peakBin];

    var totalMagnitude = 0.0;
    for (var bin = minBin; bin <= maxBin; bin++) {
      totalMagnitude += _magnitudes[bin];
    }
    if (totalMagnitude <= 0) {
      return null;
    }
    // Zero-padding spreads each window-resolution bin across
    // fftSize/windowSize FFT bins, which inflates the band sum. Normalizing
    // the non-peak sum by that ratio keeps confidence independent of fftSize
    // (equals the plain peak/total formula when windowSize == fftSize).
    final restScale = config.windowSize / config.fftSize;
    final restMagnitude = (totalMagnitude - peakMagnitude) * restScale;
    final confidence = peakMagnitude / (peakMagnitude + restMagnitude);
    if (confidence < config.minConfidence) {
      return null;
    }

    // Noise-floor estimate: mean magnitude over the search band excluding a
    // 3-bin band around the peak.
    var noiseSum = 0.0;
    var noiseCount = 0;
    for (var bin = minBin; bin <= maxBin; bin++) {
      if (bin >= peakBin - 3 && bin <= peakBin + 3) {
        continue;
      }
      noiseSum += _magnitudes[bin];
      noiseCount++;
    }
    final snrDb = (noiseCount == 0 || noiseSum <= 0)
        ? 100.0
        : 20 * math.log(peakMagnitude / (noiseSum / noiseCount)) / math.ln10;
    if (snrDb < config.minSnrDb) {
      return null;
    }

    final refinedBin = _interpolatedBin(_magnitudes, peakBin, half);
    final frequency = refinedBin * config.sampleRate / config.fftSize;

    return DetectedFrequency(
      frequency: Frequency(value: frequency),
      confidence: confidence,
      rms: rms,
      snrDb: snrDb,
    );
  }

  double _hpsScore(int bin) {
    var score = 0.0;
    for (var order = 1; order <= hpsOrders; order++) {
      final magnitude = _magnitudes[bin * order];
      score += magnitude > 0 ? math.log(magnitude) : -1000.0;
    }
    return score;
  }

  void _computeMagnitudes() {
    final fftSize = config.fftSize;
    for (var i = 0; i < config.windowSize; i++) {
      _re[i] = _windowed[i];
    }
    for (var i = config.windowSize; i < fftSize; i++) {
      _re[i] = 0.0;
    }
    for (var i = 0; i < fftSize; i++) {
      _im[i] = 0.0;
    }

    var j = 0;
    for (var i = 0; i < fftSize - 1; i++) {
      if (i < j) {
        final tmpRe = _re[i];
        _re[i] = _re[j];
        _re[j] = tmpRe;
        final tmpIm = _im[i];
        _im[i] = _im[j];
        _im[j] = tmpIm;
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
          final oddRe = _re[odd] * cosA - _im[odd] * sinA;
          final oddIm = _re[odd] * sinA + _im[odd] * cosA;
          _re[odd] = _re[even] - oddRe;
          _im[odd] = _im[even] - oddIm;
          _re[even] += oddRe;
          _im[even] += oddIm;
        }
      }
    }

    final half = fftSize >> 1;
    for (var i = 0; i <= half; i++) {
      _magnitudes[i] = math.sqrt(_re[i] * _re[i] + _im[i] * _im[i]);
    }
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