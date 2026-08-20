import 'dart:async';

import 'package:linos/data/services/audio_input_service.dart';

/// In-memory [AudioInputService] for tests: always grants microphone
/// permission and lets callers push sample buffers over a broadcast stream.
class FakeAudioInputService implements AudioInputService {
  final StreamController<List<double>> _controller =
      StreamController<List<double>>.broadcast();

  @override
  Stream<List<double>> get audioSamples => _controller.stream;

  @override
  Future<MicrophonePermissionState> checkPermission() async =>
      MicrophonePermissionState.granted;

  @override
  Future<MicrophonePermissionState> requestPermission() async =>
      MicrophonePermissionState.granted;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  void pushSamples(List<double> samples) {
    _controller.add(samples);
  }
}