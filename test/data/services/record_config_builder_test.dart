import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/services/record_config_builder.dart';
import 'package:record/record.dart';

/// Covers buildTunerRecordConfig defaults and source mapping.
void main() {
  group('buildTunerRecordConfig', () {
    test('defaults to unprocessed PCM16 mono with enhancement disabled', () {
      final config = buildTunerRecordConfig();

      expect(config.encoder, AudioEncoder.pcm16bits);
      expect(config.sampleRate, 44100);
      expect(config.numChannels, 1);
      expect(config.autoGain, isFalse);
      expect(config.echoCancel, isFalse);
      expect(config.noiseSuppress, isFalse);
      expect(config.androidConfig.audioSource, AndroidAudioSource.unprocessed);
      expect(config.androidConfig.manageBluetooth, isFalse);
      expect(config.audioInterruption, AudioInterruptionMode.pause);
      expect(config.streamBufferSize, 4096);
    });

    test('maps unprocessed source to Android unprocessed', () {
      final config = buildTunerRecordConfig(
        source: TunerAudioSource.unprocessed,
      );
      expect(config.androidConfig.audioSource, AndroidAudioSource.unprocessed);
    });

    test('maps voiceRecognition source to Android voiceRecognition', () {
      final config = buildTunerRecordConfig(
        source: TunerAudioSource.voiceRecognition,
      );
      expect(
        config.androidConfig.audioSource,
        AndroidAudioSource.voiceRecognition,
      );
    });

    test('maps mic source to Android mic', () {
      final config = buildTunerRecordConfig(source: TunerAudioSource.mic);
      expect(config.androidConfig.audioSource, AndroidAudioSource.mic);
    });

    test('uses the requested sample rate', () {
      final config = buildTunerRecordConfig(sampleRate: 48000);
      expect(config.sampleRate, 48000);
    });

    test('TunerRecordConfig.toString names source and sample rate', () {
      const info = TunerRecordConfig(
        source: TunerAudioSource.voiceRecognition,
        sampleRate: 48000,
      );
      expect(info.toString(), contains('voiceRecognition'));
      expect(info.toString(), contains('48000'));
      expect(info.toDebugMap()['source'], 'voiceRecognition');
      expect(info.toDebugMap()['sampleRate'], 48000);
    });
  });
}