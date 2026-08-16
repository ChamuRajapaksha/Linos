import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/pitch_detection.dart';
import '../../domain/use_cases/note_matcher.dart';
import '../repositories/fft_pitch_detector.dart';
import '../repositories/pitch_detector.dart';
import 'audio_input_service.dart';

class PitchDetectionService {
  PitchDetectionService({
    required AudioInputService audioInputService,
    PitchDetector? detector,
    NoteMatcher? noteMatcher,
    this.windowSize = 4096,
    this.hopSize = 2048,
  })  : _audioInputService = audioInputService,
        _detector = detector ?? FftPitchDetector(),
        _noteMatcher = noteMatcher ?? const NoteMatcher() {
    if (hopSize <= 0 || hopSize > windowSize) {
      throw ArgumentError('hopSize must be > 0 and <= windowSize');
    }
  }

  final AudioInputService _audioInputService;
  final PitchDetector _detector;
  final NoteMatcher _noteMatcher;
  final int windowSize;
  final int hopSize;

  StreamController<PitchDetection> _controller =
      StreamController<PitchDetection>.broadcast();
  StreamSubscription<List<double>>? _subscription;
  final List<double> _buffer = [];

  bool get isRunning => _subscription != null;

  Stream<PitchDetection> get pitchStream => _controller.stream;

  @visibleForTesting
  int get bufferedSampleCount => _buffer.length;

  Future<void> start() async {
    if (_subscription != null) return;
    if (_controller.isClosed) {
      _controller = StreamController<PitchDetection>.broadcast();
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
    await _subscription?.cancel();
    _subscription = null;
    _buffer.clear();
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  Future<void> dispose() async {
    await stop();
  }

  void _onSamples(List<double> samples) {
    _buffer.addAll(samples);
    while (_buffer.length >= windowSize) {
      final window = _buffer.sublist(0, windowSize);
      _buffer.removeRange(0, hopSize);
      final detected = _detector.detect(window);
      if (detected == null) {
        continue;
      }
      final match = _noteMatcher.match(detected.frequency);
      _controller.add(
        PitchDetection(
          frequency: detected.frequency,
          note: match.note,
          centsOffset: match.centsOffset,
          confidence: detected.confidence,
          rms: detected.rms,
        ),
      );
    }
  }
}