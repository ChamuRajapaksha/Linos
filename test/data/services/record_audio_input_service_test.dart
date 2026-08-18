import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/services/record_audio_input_service.dart';
import 'package:linos/data/services/record_config_builder.dart';
import 'package:record/record.dart';

/// Test seam: overrides the plugin-backed methods so unit tests stay hermetic.
class FakeRecorder extends AudioRecorder {
  final List<RecordConfig> startedConfigs = [];
  final Set<AndroidAudioSource> failingSources = {};
  int cancelCount = 0;
  Stream<Uint8List> Function()? streamFactory;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    startedConfigs.add(config);
    final source = config.androidConfig.audioSource;
    if (failingSources.contains(source)) {
      throw Exception('startStream failed for $source');
    }
    return streamFactory?.call() ?? Stream<Uint8List>.empty();
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The real AudioRecorder constructor fires a plugin `create` call; stub
    // the record method channel so constructing FakeRecorder stays hermetic.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (MethodCall call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      null,
    );
  });

  group('RecordAudioInputService fallback chain', () {
    test('starts on unprocessed when it succeeds', () async {
      final recorder = FakeRecorder();
      final service = RecordAudioInputService(recorder: recorder);

      await service.start();

      expect(recorder.startedConfigs, hasLength(1));
      expect(
        recorder.startedConfigs.single.androidConfig.audioSource,
        AndroidAudioSource.unprocessed,
      );
      expect(service.activeSource, TunerAudioSource.unprocessed);
      expect(recorder.cancelCount, 0);
    });

    test('falls back to voiceRecognition when unprocessed throws', () async {
      final recorder = FakeRecorder();
      final service = RecordAudioInputService(recorder: recorder);
      recorder.failingSources.add(AndroidAudioSource.unprocessed);

      await service.start();

      expect(recorder.startedConfigs, hasLength(2));
      expect(
        recorder.startedConfigs.last.androidConfig.audioSource,
        AndroidAudioSource.voiceRecognition,
      );
      expect(service.activeSource, TunerAudioSource.voiceRecognition);
      expect(recorder.cancelCount, 1);
    });

    test('falls back to mic when the first two sources fail', () async {
      final recorder = FakeRecorder();
      final service = RecordAudioInputService(recorder: recorder);
      recorder.failingSources
        ..add(AndroidAudioSource.unprocessed)
        ..add(AndroidAudioSource.voiceRecognition);

      await service.start();

      expect(recorder.startedConfigs, hasLength(3));
      expect(
        recorder.startedConfigs.last.androidConfig.audioSource,
        AndroidAudioSource.mic,
      );
      expect(service.activeSource, TunerAudioSource.mic);
      expect(recorder.cancelCount, 2);
    });

    test('throws AudioInputException and stays unlocked when all sources fail',
        () async {
      final recorder = FakeRecorder();
      final service = RecordAudioInputService(recorder: recorder);
      recorder.failingSources.addAll(AndroidAudioSource.values);

      await expectLater(
        service.start(),
        throwsA(isA<AudioInputException>()
            .having(
              (e) => e.message,
              'message',
              contains('Failed to start audio capture'),
            )
            .having((e) => e.cause, 'cause', isNotNull)),
      );

      expect(service.activeSource, isNull);
      expect(recorder.startedConfigs, hasLength(3));
      expect(recorder.cancelCount, 3);
    });

    test('startStreamOverride is used in place of the recorder', () async {
      final recorder = FakeRecorder();
      final seen = <RecordConfig>[];
      final service = RecordAudioInputService(
        recorder: recorder,
        startStreamOverride: (config) async {
          seen.add(config);
          return Stream<Uint8List>.empty();
        },
      );

      await service.start();

      expect(recorder.startedConfigs, isEmpty);
      expect(seen, hasLength(1));
      expect(
        seen.single.androidConfig.audioSource,
        AndroidAudioSource.unprocessed,
      );
      expect(service.activeSource, TunerAudioSource.unprocessed);
    });

    test('override-based chain cancels the recorder between failures', () async {
      final recorder = FakeRecorder();
      final service = RecordAudioInputService(
        recorder: recorder,
        startStreamOverride: (config) async {
          final source = config.androidConfig.audioSource;
          if (source == AndroidAudioSource.unprocessed) {
            throw Exception('unprocessed unavailable');
          }
          return Stream<Uint8List>.empty();
        },
      );

      await service.start();

      expect(service.activeSource, TunerAudioSource.voiceRecognition);
      expect(recorder.cancelCount, 1);
    });

    test('passes the tuner config through to the winning source', () async {
      final recorder = FakeRecorder();
      final service = RecordAudioInputService(recorder: recorder);

      await service.start();

      final config = recorder.startedConfigs.single;
      expect(config.encoder, AudioEncoder.pcm16bits);
      expect(config.sampleRate, 44100);
      expect(config.numChannels, 1);
      expect(config.autoGain, isFalse);
      expect(config.echoCancel, isFalse);
      expect(config.noiseSuppress, isFalse);
      expect(config.androidConfig.manageBluetooth, isFalse);
      expect(config.audioInterruption, AudioInterruptionMode.pause);
    });
  });

  group('RecordAudioInputService stream handling', () {
    test('emits PCM16 bytes converted to doubles on audioSamples', () async {
      final controller = StreamController<Uint8List>.broadcast();
      final recorder = FakeRecorder()..streamFactory = () => controller.stream;
      final service = RecordAudioInputService(recorder: recorder);
      final samples = <List<double>>[];
      service.audioSamples.listen(samples.add);

      await service.start();

      // Two little-endian 16-bit samples: 16384 -> 0.5, -16384 -> -0.5.
      controller.add(Uint8List.fromList([0x00, 0x40, 0x00, 0xC0]));
      await pumpEventQueue();

      expect(samples, isNotEmpty);
      expect(samples.single, [0.5, -0.5]);

      await controller.close();
      await service.stop();
    });
  });
}