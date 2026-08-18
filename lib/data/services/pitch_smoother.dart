import 'dart:math' as math;

import '../models/detected_frequency.dart';

/// A stable pitch reading emitted by [PitchSmoother].
class SmoothedPitch {
  const SmoothedPitch({
    required this.frequency,
    required this.confidence,
    required this.rms,
    required this.snrDb,
  });

  final double frequency;
  final double confidence;
  final double rms;
  final double snrDb;

  @override
  bool operator ==(Object other) {
    return other is SmoothedPitch &&
        other.frequency == frequency &&
        other.confidence == confidence &&
        other.rms == rms &&
        other.snrDb == snrDb;
  }

  @override
  int get hashCode => Object.hash(frequency, confidence, rms, snrDb);
}

/// Temporal pitch-stability layer with lock-on/lock-out hysteresis.
///
/// Raw per-frame detections flicker and jump octaves; this keeps the needle
/// steady by only emitting a value once a candidate has been consistent for
/// [lockOnFrames], holding the current value while an outlier appears, and
/// only switching strings after [lockOffFrames] consistent far-off readings.
class PitchSmoother {
  PitchSmoother({
    this.lockOnFrames = 3,
    this.lockOffFrames = 2,
    this.maxLockCents = 40,
    this.switchThresholdCents = 60,
    this.emaAlpha = 0.35,
    this.minConfidenceToHold = 0.1,
    this.maxHeldFrames = 15,
  })  : assert(lockOnFrames >= 1),
        assert(lockOffFrames >= 1),
        assert(maxLockCents >= 0),
        assert(switchThresholdCents > maxLockCents),
        assert(emaAlpha >= 0 && emaAlpha <= 1),
        assert(maxHeldFrames >= 0);

  /// Consistent candidate frames required to acquire a note.
  final int lockOnFrames;

  /// Consistent far-off frames required to switch away from a note.
  final int lockOffFrames;

  /// Maximum cents from the current value to be treated as the same note.
  final double maxLockCents;

  /// Minimum cents offset for a reading to be treated as a string change.
  final double switchThresholdCents;

  /// EMA smoothing factor applied per accepted frame.
  final double emaAlpha;

  /// Below this confidence, an accepted detection barely nudges the value.
  final double minConfidenceToHold;

  /// Consecutive silent frames before the lock is released.
  final int maxHeldFrames;

  final List<double> _candidateFreqs = <double>[];
  final List<double> _pendingSwitchFreqs = <double>[];
  double? _currentFreq;
  int _heldCount = 0;
  bool _locked = false;

  /// Whether the smoother currently holds a locked note.
  bool get isLocked => _locked;

  /// Processes one detection, returning null until a note is locked.
  SmoothedPitch? process(DetectedFrequency detection) {
    final freq = detection.frequency.value;
    if (!_locked) {
      return _processUnlocked(detection, freq);
    }
    return _processLocked(detection, freq);
  }

  /// Signals that a frame produced no detection.
  void noDetection() {
    _heldCount++;
    if (_heldCount > maxHeldFrames) {
      reset();
    }
  }

  /// Clears all state, dropping any candidate, lock and pending switch.
  void reset() {
    _candidateFreqs.clear();
    _pendingSwitchFreqs.clear();
    _currentFreq = null;
    _heldCount = 0;
    _locked = false;
  }

  SmoothedPitch? _processUnlocked(DetectedFrequency detection, double freq) {
    if (_candidateFreqs.isEmpty) {
      _candidateFreqs.add(freq);
    } else if (_centsBetween(freq, _candidateFreqs.last).abs() <=
        maxLockCents) {
      _candidateFreqs.add(freq);
    } else {
      _candidateFreqs
        ..clear()
        ..add(freq);
    }
    _heldCount = 0;
    if (_candidateFreqs.length >= lockOnFrames) {
      final median = _median(_candidateFreqs);
      _locked = true;
      _currentFreq = median;
      _candidateFreqs.clear();
      return SmoothedPitch(
        frequency: median,
        confidence: detection.confidence,
        rms: detection.rms,
        snrDb: detection.snrDb,
      );
    }
    return null;
  }

  SmoothedPitch _processLocked(DetectedFrequency detection, double freq) {
    final current = _currentFreq!;
    final absCents = _centsBetween(freq, current).abs();
    _heldCount = 0;

    if (absCents <= maxLockCents) {
      _pendingSwitchFreqs.clear();
      var alpha = emaAlpha * (0.5 + 0.5 * detection.confidence);
      if (detection.confidence < minConfidenceToHold) {
        alpha *= 0.25;
      }
      _currentFreq = current + alpha * (freq - current);
      return SmoothedPitch(
        frequency: _currentFreq!,
        confidence: detection.confidence,
        rms: detection.rms,
        snrDb: detection.snrDb,
      );
    }

    if (absCents < switchThresholdCents) {
      // Outlier in the guard band: hold the current value, no switch.
      _pendingSwitchFreqs.clear();
      return SmoothedPitch(
        frequency: current,
        confidence: detection.confidence,
        rms: detection.rms,
        snrDb: detection.snrDb,
      );
    }

    // Far-off reading: potential string change / octave flip.
    if (_pendingSwitchFreqs.isEmpty ||
        _centsBetween(freq, _pendingSwitchFreqs.last).abs() > maxLockCents) {
      _pendingSwitchFreqs
        ..clear()
        ..add(freq);
    } else {
      _pendingSwitchFreqs.add(freq);
    }
    if (_pendingSwitchFreqs.length >= lockOffFrames) {
      final median = _median(_pendingSwitchFreqs);
      _currentFreq = median;
      _pendingSwitchFreqs.clear();
      return SmoothedPitch(
        frequency: median,
        confidence: detection.confidence,
        rms: detection.rms,
        snrDb: detection.snrDb,
      );
    }
    // Switch pending: keep emitting the held value so the needle stays still.
    return SmoothedPitch(
      frequency: current,
      confidence: detection.confidence,
      rms: detection.rms,
      snrDb: detection.snrDb,
    );
  }

  double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isEven) {
      return (sorted[mid - 1] + sorted[mid]) / 2;
    }
    return sorted[mid];
  }

  double _centsBetween(double a, double b) =>
      1200 * math.log(a / b) / math.ln2;
}