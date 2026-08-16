import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/repositories/fft_pitch_detector.dart';
import 'package:linos/data/repositories/pitch_detector.dart';
import 'package:linos/data/services/audio_input_service.dart';
import 'package:linos/data/services/pitch_detection_service.dart';
import 'package:linos/domain/models/pitch_detection.dart';

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

List<double> sine(double freq, int count, {double amplitude = 0.5}) {
  const int sampleRate = 44100;
  return List<double>.generate(
    count,
    (int i) => amplitude * math.sin(2 * math.pi * freq * i / sampleRate),
  );
}

PitchDetectionService buildService(FakeAudioInputService audio) {
  return PitchDetectionService(
    audioInputService: audio,
    detector: FftPitchDetector(
      config: const PitchDetectorConfig(
        windowSize: 1024,
        fftSize: 8192,
        sampleRate: 44100,
      ),
    ),
    windowSize: 1024,
    hopSize: 512,
  );
}

void main() {
  group('PitchDetectionService', () {
    test('detects A4 (440 Hz) from a sine fed in chunks', () async {
      final audio = FakeAudioInputService();
      final service = buildService(audio);
      final detections = <PitchDetection>[];
      service.pitchStream.listen(detections.add);

      await service.start();

      final signal = sine(440, 4096);
      for (var i = 0; i < signal.length; i += 512) {
        audio.pushSamples(signal.sublist(i, i + 512));
      }
      await pumpEventQueue();

      expect(detections, isNotEmpty);
      final first = detections.first;
      expect(first.frequency.value, closeTo(440, 1.5));
      expect(first.note.label, 'A4');
      expect(first.centsOffset, closeTo(0, 1.0));
      expect(first.confidence, greaterThan(0));
      expect(first.rms, greaterThan(0));

      await service.stop();
    });

    test('detects E2 (82.41 Hz) from a sine fed in chunks', () async {
      final audio = FakeAudioInputService();
      final service = buildService(audio);
      final detections = <PitchDetection>[];
      service.pitchStream.listen(detections.add);

      await service.start();

      final signal = sine(82.41, 8192);
      for (var i = 0; i < signal.length; i += 1024) {
        audio.pushSamples(signal.sublist(i, i + 1024));
      }
      await pumpEventQueue();

      expect(detections, isNotEmpty);
      final first = detections.first;
      expect(first.frequency.value, closeTo(82.41, 1.5));
      expect(first.note.label, 'E2');

      await service.stop();
    });

    test('silence produces no detections', () async {
      final audio = FakeAudioInputService();
      final service = buildService(audio);
      final detections = <PitchDetection>[];
      service.pitchStream.listen(detections.add);

      await service.start();

      for (var i = 0; i < 4; i++) {
        audio.pushSamples(List<double>.filled(512, 0));
        await pumpEventQueue();
      }

      expect(detections, isEmpty);

      await service.stop();
    });

    test('internal buffer stays bounded while processing many chunks', () async {
      final audio = FakeAudioInputService();
      final service = buildService(audio);

      await service.start();

      final signal = sine(440, 51200);
      for (var i = 0; i < signal.length; i += 512) {
        audio.pushSamples(signal.sublist(i, i + 512));
      }
      await pumpEventQueue();

      expect(service.bufferedSampleCount, lessThan(1024 + 512));

      await service.stop();
    });

    test('stop cancels the subscription and start resumes detection', () async {
      final audio = FakeAudioInputService();
      final service = buildService(audio);
      final detections = <PitchDetection>[];
      service.pitchStream.listen(detections.add);

      await service.start();
      expect(service.isRunning, isTrue);

      audio.pushSamples(sine(440, 1024));
      await pumpEventQueue();
      final countBeforeStop = detections.length;
      expect(countBeforeStop, greaterThan(0));

      await service.stop();
      expect(service.isRunning, isFalse);

      audio.pushSamples(sine(440, 1024));
      await pumpEventQueue();
      expect(detections.length, countBeforeStop);

      await service.start();
      expect(service.isRunning, isTrue);
      final after = <PitchDetection>[];
      service.pitchStream.listen(after.add);
      audio.pushSamples(sine(440, 1024));
      await pumpEventQueue();
      expect(after, isNotEmpty);

      await service.stop();
    });
  });
}