import 'dart:math' as math;

import '../../domain/models/frequency.dart';
import '../models/detected_frequency.dart';
import 'pitch_detector.dart';

/// Time-domain pitch detector implementing the YIN algorithm
/// (de Cheveigne & Kawahara 2002).
///
/// Works directly on raw samples (no windowing) using the cumulative-mean
/// normalized difference function. Robust to strong harmonics because the
/// fundamental period produces the deepest dip in the CMNDF.
class YinPitchDetector implements PitchDetector {
  YinPitchDetector({this.config = const PitchDetectorConfig()}) {
    if (config.windowSize < 2) {
      throw ArgumentError('windowSize must be at least 2');
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

    _difference = List<double>.filled(config.windowSize ~/ 2 + 2, 0);
    _cumulative = List<double>.filled(config.windowSize ~/ 2 + 2, 0);
  }

  // YIN absolute-threshold: a lag is a pitch candidate when its CMNDF dips
  // below this value. A pure tone dips to ~0; noise stays near 1.
  static const double threshold = 0.10;

  final PitchDetectorConfig config;

  late final List<double> _difference;
  late final List<double> _cumulative;

  @override
  DetectedFrequency? detect(List<double> samples) {
    if (samples.length != config.windowSize) {
      throw ArgumentError(
        'samples.length (${samples.length}) must equal windowSize '
        '(${config.windowSize})',
      );
    }

    final windowSize = config.windowSize;

    var sumOfSquares = 0.0;
    for (var i = 0; i < windowSize; i++) {
      sumOfSquares += samples[i] * samples[i];
    }
    final rms = math.sqrt(sumOfSquares / windowSize);
    if (rms < config.minRms) {
      return null;
    }

    // Only search lags corresponding to [minFrequency, maxFrequency]; this
    // prevents octave-down drift on very low inputs.
    final tauMin =
        math.max(2, (config.sampleRate / config.maxFrequency).floor());
    final tauMax =
        math.min(windowSize ~/ 2, (config.sampleRate / config.minFrequency).ceil());
    if (tauMin > tauMax) {
      return null;
    }

    var runningSum = 0.0;
    for (var tau = 1; tau <= tauMax; tau++) {
      var sum = 0.0;
      final limit = windowSize - tau;
      for (var i = 0; i < limit; i++) {
        final diff = samples[i] - samples[i + tau];
        sum += diff * diff;
      }
      _difference[tau] = sum;
      runningSum += sum;
      _cumulative[tau] =
          runningSum <= 0 ? 1.0 : sum * tau / runningSum;
    }
    _cumulative[0] = 1.0;

    // Absolute threshold: the smallest tau in [tauMin, tauMax] whose CMNDF is
    // below the threshold AND a local minimum. Requiring a local minimum
    // skips the descending flank of the dip so we land on the true period.
    var tauCandidate = -1;
    for (var tau = tauMin; tau <= tauMax; tau++) {
      if (_cumulative[tau] >= threshold) {
        continue;
      }
      final leftOk = tau == tauMin || _cumulative[tau] <= _cumulative[tau - 1];
      final rightOk =
          tau == tauMax || _cumulative[tau] < _cumulative[tau + 1];
      if (leftOk && rightOk) {
        tauCandidate = tau;
        break;
      }
    }

    if (tauCandidate < 0) {
      // No dip below threshold: fall back to the global minimum. If it is not
      // meaningfully below 1 the signal is aperiodic (noise).
      var best = tauMin;
      for (var tau = tauMin; tau <= tauMax; tau++) {
        if (_cumulative[tau] < _cumulative[best]) {
          best = tau;
        }
      }
      if (_cumulative[best] > 0.5) {
        return null;
      }
      tauCandidate = best;
    }

    final cmndfAtMin = _cumulative[tauCandidate];
    final confidence = 1.0 - cmndfAtMin;
    if (confidence < config.minConfidence) {
      return null;
    }

    // Periodicity SNR proxy: a deep periodic dip (small CMNDF) is high dB.
    final snrDb = -20 * math.log(cmndfAtMin) / math.ln10;
    if (snrDb < config.minSnrDb) {
      return null;
    }

    final tauRefined = _refinedTau(tauCandidate, tauMax);
    final frequency = config.sampleRate / tauRefined;

    return DetectedFrequency(
      frequency: Frequency(value: frequency),
      confidence: confidence,
      rms: rms,
      snrDb: snrDb,
    );
  }

  // Parabolic interpolation on the CMNDF around the candidate lag.
  double _refinedTau(int tau, int tauMax) {
    if (tau <= 1 || tau >= tauMax) {
      return tau.toDouble();
    }
    final y0 = _cumulative[tau - 1];
    final y1 = _cumulative[tau];
    final y2 = _cumulative[tau + 1];
    final denominator = y0 - 2 * y1 + y2;
    if (denominator.abs() < 1e-12) {
      return tau.toDouble();
    }
    final delta = 0.5 * (y0 - y2) / denominator;
    final refined = tau + delta;
    if (!refined.isFinite || refined < 1) {
      return tau.toDouble();
    }
    return refined;
  }
}