import 'package:record/record.dart';

/// Audio sources a guitar tuner can capture from, in preference order.
///
/// [unprocessed] requests raw mic input with no Android voice-processing,
/// [voiceRecognition] maps to the platform voice-recognition source, and
/// [mic] is the plain microphone source used as a last resort.
enum TunerAudioSource { unprocessed, voiceRecognition, mic }

/// Description of a tuner capture configuration, for logging/device tests.
class TunerRecordConfig {
  const TunerRecordConfig({required this.source, required this.sampleRate});

  final TunerAudioSource source;
  final int sampleRate;

  @override
  String toString() =>
      'TunerRecordConfig(source: ${source.name}, sampleRate: $sampleRate)';

  Map<String, dynamic> toDebugMap() => {
        'source': source.name,
        'sampleRate': sampleRate,
      };
}

AndroidAudioSource _mapAndroidSource(TunerAudioSource source) {
  switch (source) {
    case TunerAudioSource.unprocessed:
      return AndroidAudioSource.unprocessed;
    case TunerAudioSource.voiceRecognition:
      return AndroidAudioSource.voiceRecognition;
    case TunerAudioSource.mic:
      return AndroidAudioSource.mic;
  }
}

/// Builds the [RecordConfig] used by the tuner capture service.
///
/// PCM16 mono at [sampleRate] (44.1 kHz by default), with all enhancement
/// (AGC, echo cancel, noise
/// suppression) explicitly disabled so the pitch detector sees raw signal.
/// `streamBufferSize` keeps stream chunks at 4096 bytes (2048 mono samples).
RecordConfig buildTunerRecordConfig({
  int sampleRate = 44100,
  TunerAudioSource source = TunerAudioSource.unprocessed,
}) {
  return RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: sampleRate,
    numChannels: 1,
    autoGain: false,
    echoCancel: false,
    noiseSuppress: false,
    androidConfig: AndroidRecordConfig(
      audioSource: _mapAndroidSource(source),
      manageBluetooth: false,
    ),
    audioInterruption: AudioInterruptionMode.pause,
    streamBufferSize: 4096,
  );
}
