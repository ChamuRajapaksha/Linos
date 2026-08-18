import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/frequency.dart';
import '../../domain/models/pitch_detection.dart';
import '../../domain/use_cases/note_matcher.dart';
import '../models/detected_frequency.dart';
import '../repositories/isolate_pitch_detector.dart';
import '../repositories/pitch_detector.dart';
import '../repositories/yin_pitch_detector.dart';
import 'audio_input_service.dart';
import 'pitch_smoother.dart';

/// Continuous pitch detection over the live audio stream.
///
/// Buffers incoming samples into sliding windows, runs a [PitchDetector] on
/// each one (optionally on a compute isolate to keep the UI thread free),
/// passes the raw readings through a [PitchSmoother] for temporal stability,
/// and maps the smoothed frequency to a note before emitting a [PitchDetection].
class PitchDetectionService {
  PitchDetectionService({
    required AudioInputService audioInputService,
    PitchDetector? detector,
    NoteMatcher? noteMatcher,
    PitchSmoother? smoother,
    this.windowSize = 4096,
    this.hopSize = 2048,
    this.useIsolate = false,
    this.isolateKind = DetectorKind.yin,
    this.maxPendingWindows = 6,
  })  : assert(
          detector == null || !useIsolate,
          'provide either a synchronous detector or useIsolate, not both',
        ),
        _audioInputService = audioInputService,
        _detector = detector ??
            (useIsolate
                ? null
                : YinPitchDetector(config: const PitchDetectorConfig())),
        _noteMatcher = noteMatcher ?? const NoteMatcher(),
        _smoother = smoother ?? PitchSmoother() {
    if (hopSize <= 0 || hopSize > windowSize) {
      throw ArgumentError('hopSize must be > 0 and <= windowSize');
    }
  }

  final AudioInputService _audioInputService;
  final PitchDetector? _detector;
  final NoteMatcher _noteMatcher;
  final PitchSmoother _smoother;
  final int windowSize;
  final int hopSize;
  final bool useIsolate;
  final DetectorKind isolateKind;
  final int maxPendingWindows;

  StreamController<PitchDetection> _controller =
      StreamController<PitchDetection>.broadcast();
  StreamSubscription<List<double>>? _subscription;
  final List<double> _buffer = [];
  IsolatePitchDetector? _worker;
  bool _running = false;

  bool get isRunning => _subscription != null;

  Stream<PitchDetection> get pitchStream => _controller.stream;

  @visibleForTesting
  int get bufferedSampleCount => _buffer.length;

  /// Number of sample windows awaiting a worker response (0 without isolates).
  @visibleForTesting
  int get pendingWorkerCount => _worker?.pendingCount ?? 0;

  /// The temporal stability layer used to gate and smooth raw readings.
  @visibleForTesting
  PitchSmoother get smoother => _smoother;

  Future<void> start() async {
    if (_subscription != null) return;
    if (_controller.isClosed) {
      _controller = StreamController<PitchDetection>.broadcast();
    }
    _running = true;
    if (useIsolate) {
      _worker ??= IsolatePitchDetector(
        kind: isolateKind,
        config: const PitchDetectorConfig(),
      );
      try {
        await _worker!.ensureStarted();
      } catch (error, stackTrace) {
        _running = false;
        _controller.addError(error, stackTrace);
        return;
      }
    }
    _subscription = _audioInputService.audioSamples.listen(
      _onSamples,
      onError: (Object error, StackTrace stackTrace) =>
          _controller.addError(error, stackTrace),
      onDone: () {
        _subscription = null;
      },
    );
  }

  Future<void> stop() async {
    _running = false;
    await _subscription?.cancel();
    _subscription = null;
    _buffer.clear();
    _smoother.reset();
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  Future<void> dispose() async {
    await stop();
    await _worker?.dispose();
    _worker = null;
  }

  void _onSamples(List<double> samples) {
    _buffer.addAll(samples);
    while (_buffer.length >= windowSize) {
      final window = _buffer.sublist(0, windowSize);
      _buffer.removeRange(0, hopSize);
      if (useIsolate) {
        final worker = _worker!;
        if (worker.pendingCount >= maxPendingWindows) {
          continue;
        }
        unawaited(
          worker
              .detect(window)
              .then(_onDetectionResult)
              .catchError((Object error, StackTrace stackTrace) {
            if (_running) {
              _controller.addError(error, stackTrace);
            }
          }),
        );
      } else {
        _onDetectionResult(_detector!.detect(window));
      }
    }
  }

  void _onDetectionResult(DetectedFrequency? detected) {
    if (!_running) return;
    if (detected == null) {
      _smoother.noDetection();
      return;
    }
    final smoothed = _smoother.process(detected);
    if (smoothed == null) {
      return;
    }
    final frequency = Frequency(value: smoothed.frequency);
    final match = _noteMatcher.match(frequency);
    _controller.add(
      PitchDetection(
        frequency: frequency,
        note: match.note,
        centsOffset: match.centsOffset,
        confidence: smoothed.confidence,
        rms: smoothed.rms,
        snrDb: smoothed.snrDb,
      ),
    );
  }
}
