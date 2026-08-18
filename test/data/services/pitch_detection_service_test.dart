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

/// Covers the detection service: buffering, gates, smoothing, isolate path.
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

      audio.pushSamples(sine(440, 3072));
      await pumpEventQueue();
      final countBeforeStop = detections.length;
      expect(countBeforeStop, greaterThan(0));

      await service.stop();
      expect(service.isRunning, isFalse);

      audio.pushSamples(sine(440, 3072));
      await pumpEventQueue();
      expect(detections.length, countBeforeStop);

      await service.start();
      expect(service.isRunning, isTrue);
      final after = <PitchDetection>[];
      service.pitchStream.listen(after.add);
      audio.pushSamples(sine(440, 3072));
      await pumpEventQueue();
      expect(after, isNotEmpty);

      await service.stop();
    });

    test('emits nothing until the smoother locks on three windows', () async {
      final audio = FakeAudioInputService();
      final service = buildService(audio);
      final detections = <PitchDetection>[];
      service.pitchStream.listen(detections.add);

      await service.start();

      final signal = sine(440, 4096);
      // 3 chunks = 2 windows: lock-on needs 3 consistent windows.
      for (var i = 0; i < 3; i++) {
        audio.pushSamples(signal.sublist(i * 512, (i + 1) * 512));
        await pumpEventQueue();
      }
      expect(detections, isEmpty);

      // 3 more chunks complete the third window and lock-on.
      for (var i = 3; i < 6; i++) {
        audio.pushSamples(signal.sublist(i * 512, (i + 1) * 512));
        await pumpEventQueue();
      }
      expect(detections, hasLength(3));
      expect(detections.first.frequency.value, closeTo(440, 1.5));
      expect(detections.first.note.label, 'A4');

      await service.stop();
    });

    test('runs detection on a compute isolate end to end', () async {
      final audio = FakeAudioInputService();
      final service = PitchDetectionService(
        audioInputService: audio,
        useIsolate: true,
      );
      final detections = <PitchDetection>[];
      service.pitchStream.listen(detections.add);

      await service.start();

final signal = sine(440, 16384);
      for (var i = 0; i < signal.length; i += 512) {
        audio.pushSamples(signal.sublist(i, i + 512));
        await pumpEventQueue();
      }
      final deadline =
          DateTime.now().add(const Duration(milliseconds: 5000));
      while (service.pendingWorkerCount > 0 &&
          DateTime.now().isBefore(deadline)) {
        await pumpEventQueue();
      }

      expect(detections, isNotEmpty);
      expect(detections.first.frequency.value, closeTo(440, 1.5));
      expect(detections.first.note.label, 'A4');

      await service.dispose();
    });

    test('caps in-flight worker windows under backpressure', () async {
      final audio = FakeAudioInputService();
      final service = PitchDetectionService(
        audioInputService: audio,
        useIsolate: true,
        maxPendingWindows: 2,
      );

      await service.start();

      // One giant chunk produces many windows in a single _onSamples call.
      audio.pushSamples(sine(440, 4096 * 20));
      for (var i = 0; i < 30; i++) {
        await pumpEventQueue();
      }

      expect(service.pendingWorkerCount, lessThanOrEqualTo(2));

      await service.dispose();
    });

    test('re-locks after sustained silence', () async {
      final audio = FakeAudioInputService();
      final service = buildService(audio);
      final detections = <PitchDetection>[];
      service.pitchStream.listen(detections.add);

      await service.start();

      final signal = sine(440, 4096);
      for (var i = 0; i < 8; i++) {
        audio.pushSamples(signal.sublist(i * 512, (i + 1) * 512));
        await pumpEventQueue();
      }
      expect(detections, isNotEmpty);

      // Silence beyond maxHeldFrames (15) releases the lock.
      for (var i = 0; i < 20; i++) {
        audio.pushSamples(List<double>.filled(512, 0));
        await pumpEventQueue();
      }
      expect(service.smoother.isLocked, isFalse);

      // A fresh burst re-locks and emits again.
      final countBefore = detections.length;
      for (var i = 0; i < 8; i++) {
        audio.pushSamples(signal.sublist(i * 512, (i + 1) * 512));
        await pumpEventQueue();
      }
      expect(detections.length, greaterThan(countBefore));

      await service.stop();
    });
});
}
