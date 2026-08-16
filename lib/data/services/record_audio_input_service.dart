import 'dart:async';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'audio_input_service.dart';

class AudioInputException implements Exception {
  AudioInputException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message: $cause';
}

class RecordAudioInputService implements AudioInputService {
  RecordAudioInputService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  StreamController<List<double>> _controller =
      StreamController<List<double>>.broadcast();
  StreamSubscription<Uint8List>? _subscription;
  bool _isStreaming = false;

  @override
  Future<MicrophonePermissionState> checkPermission() async {
    final status = await Permission.microphone.status;
    return _mapPermissionStatus(status);
  }

  @override
  Future<MicrophonePermissionState> requestPermission() async {
    final status = await Permission.microphone.request();
    return _mapPermissionStatus(status);
  }

  @override
  Future<void> start() async {
    if (_isStreaming) return;
    if (_controller.isClosed) {
      _controller = StreamController<List<double>>.broadcast();
    }
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions
                .allowBluetooth |
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.measurement,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
      ));
      _subscription = stream.listen(
        (bytes) => _controller.add(_convertPcm16ToDoubles(bytes)),
        onError: (Object error, StackTrace stackTrace) => _controller.addError(
          AudioInputException('Audio stream failed', error),
          stackTrace,
        ),
      );
      _isStreaming = true;
    } on AudioInputException {
      rethrow;
    } catch (error) {
      throw AudioInputException('Failed to start audio capture', error);
    }
  }

  @override
  Future<void> stop() async {
    if (!_isStreaming) return;
    _isStreaming = false;
    await _subscription?.cancel();
    _subscription = null;
    if (!_controller.isClosed) {
      await _controller.close();
    }
    try {
      await _recorder.stop();
    } catch (error) {
      throw AudioInputException('Failed to stop audio capture', error);
    }
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }

  @override
  Stream<List<double>> get audioSamples => _controller.stream;

  MicrophonePermissionState _mapPermissionStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return MicrophonePermissionState.granted;
      case PermissionStatus.denied:
        return MicrophonePermissionState.denied;
      case PermissionStatus.permanentlyDenied:
        return MicrophonePermissionState.permanentlyDenied;
      case PermissionStatus.restricted:
        return MicrophonePermissionState.restricted;
      case PermissionStatus.limited:
      case PermissionStatus.provisional:
        return MicrophonePermissionState.unknown;
    }
  }

  List<double> _convertPcm16ToDoubles(Uint8List bytes) {
    final byteData = ByteData.sublistView(bytes);
    final sampleCount = bytes.length ~/ 2;
    final samples = List<double>.filled(sampleCount, 0);
    for (var i = 0; i < sampleCount; i++) {
      samples[i] = byteData.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }
}