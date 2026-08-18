import 'dart:async';
import 'dart:isolate';

import '../models/detected_frequency.dart';
import 'fft_pitch_detector.dart';
import 'pitch_detector.dart';
import 'yin_pitch_detector.dart';

/// Which pitch-detection algorithm to run inside the worker isolate.
enum DetectorKind { yin, fft }

/// Runs a [PitchDetector] in a dedicated compute isolate so pitch detection
/// never blocks the UI thread or stalls the audio processing pipeline.
///
/// Sample windows are copied across the isolate boundary and [DetectedFrequency]
/// results come back asynchronously. Only plain (sendable) data is exchanged:
/// `[id, List<double>]` requests and `[id, DetectedFrequency?|String]` responses.
class IsolatePitchDetector {
  IsolatePitchDetector({required this.kind, required this.config});

  final DetectorKind kind;
  final PitchDetectorConfig config;

  Isolate? _isolate;
  ReceivePort? _responsePort;
  SendPort? _requestPort;
  Future<void>? _startFuture;
  Completer<void>? _handshake;
  int _nextId = 0;
  bool _disposed = false;
  final Map<int, Completer<DetectedFrequency?>> _pending = {};

  /// Number of in-flight detections awaiting a response.
  int get pendingCount => _pending.length;

  /// Lazily spawns the worker isolate and awaits its ready handshake.
  Future<void> ensureStarted() {
    if (_disposed) {
      return Future.error(StateError('IsolatePitchDetector has been disposed'));
    }
    return _startFuture ??= _start();
  }

  /// Sends a window to the worker. The returned future completes when the
  /// worker reports back (or with an error if the worker failed/disposed).
  ///
  /// The pending entry is registered synchronously so callers can enforce
  /// backpressure via [pendingCount] before the send is flushed.
  Future<DetectedFrequency?> detect(List<double> window) {
    if (_disposed) {
      return Future.error(StateError('IsolatePitchDetector has been disposed'));
    }
    final id = _nextId++;
    final completer = Completer<DetectedFrequency?>();
    _pending[id] = completer;
    ensureStarted().then(
      (_) => _requestPort?.send([id, window]),
      onError: (Object error, StackTrace stackTrace) {
        if (_pending.remove(id) == null) {
          return;
        }
        completer.completeError(error, stackTrace);
      },
    );
    return completer.future;
  }

  /// Tears down the worker isolate and fails any in-flight detections.
  Future<void> dispose() async {
    _disposed = true;
    final isolate = _isolate;
    final responsePort = _responsePort;
    _isolate = null;
    _responsePort = null;
    _requestPort = null;
    _startFuture = null;
    final handshake = _handshake;
    if (handshake != null && !handshake.isCompleted) {
      handshake.complete();
    }
    _handshake = null;
    if (isolate != null) {
      isolate.kill(priority: Isolate.immediate);
    }
    responsePort?.close();
    final pending = _pending.values.toList();
    _pending.clear();
    for (final completer in pending) {
      completer.completeError(StateError('IsolatePitchDetector disposed'));
    }
    _nextId = 0;
  }

  Future<void> _start() async {
    final responsePort = ReceivePort();
    _responsePort = responsePort;
    final handshake = Completer<void>();
    _handshake = handshake;
    _isolate = await Isolate.spawn(
      _workerEntry,
      (kind, config, responsePort.sendPort),
    );
    responsePort.listen(_onResponse);
    await handshake.future;
  }

  void _onResponse(dynamic message) {
    if (_requestPort == null) {
      // First message is the worker's ready handshake.
      if (message is SendPort) {
        _requestPort = message;
        _handshake?.complete();
      }
      return;
    }
    if (message is! List || message.length != 2 || message[0] is! int) {
      return;
    }
    final id = message[0] as int;
    final completer = _pending.remove(id);
    if (completer == null) {
      return;
    }
    final result = message[1];
    if (result is DetectedFrequency) {
      completer.complete(result);
    } else {
      completer.completeError(StateError('Detector failed: $result'));
    }
  }

  static Future<void> _workerEntry(
    (DetectorKind, PitchDetectorConfig, SendPort) args,
  ) async {
    final (kind, config, responsePort) = args;
    final PitchDetector detector = switch (kind) {
      DetectorKind.yin => YinPitchDetector(config: config),
      DetectorKind.fft => FftPitchDetector(config: config),
    };
    final requestPort = ReceivePort();
    responsePort.send(requestPort.sendPort);
    await for (final message in requestPort) {
      if (message is! List ||
          message.length != 2 ||
          message[0] is! int ||
          message[1] is! List) {
        continue;
      }
      final id = message[0] as int;
      final window = (message[1] as List).cast<double>();
      try {
        responsePort.send([id, detector.detect(window)]);
      } catch (error) {
        responsePort.send([id, error.toString()]);
      }
    }
  }
}