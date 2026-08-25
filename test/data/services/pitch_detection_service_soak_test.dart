@Tags(['soak'])
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/services/pitch_detection_service.dart';
import 'package:linos/domain/models/pitch_detection.dart';

import '../../helpers/fake_audio_input_service.dart';
import '../../helpers/guitar_signal.dart';

/// Headless 2-minute soak of the production detection pipeline.
///
/// Software-only replacement for the on-device soak in
/// `integration_test/tuner_e2e_test.dart`: instead of a microphone it pumps
/// synthetic harmonic-rich guitar audio through the PRODUCTION detection
/// pipeline (compute isolate, windowSize 4096, hopSize 2048,
/// maxPendingWindows 6, YIN) for 2 real minutes and asserts that no errors
/// surface, the sample buffer never grows unboundedly, and RSS does not grow.
///
/// Run with:
///
///   flutter test --tags soak --dart-define=RUN_SOAK=true
///
/// Skipped by default (it runs for a full 2 minutes) unless `RUN_SOAK` is set.
const bool _runSoak = bool.fromEnvironment('RUN_SOAK');

void main() {
  test(
    'soaks the isolate pipeline with synthetic guitar audio for 2 minutes',
    () async {
      const int sampleRate = 44100;
      const List<double> detuneCents = [-30, 30, -30, 30, -30, 30];
      const int chunkSize = 512;

      // Precompute all audio up front so the soak itself does not leak
      // allocations: one 1.5 s pluck per open string plus a silence buffer.
      final plucks = [
        for (var i = 0; i < standardTuningFrequencies.length; i++)
          generatePluckedString(
            frequency: standardTuningFrequencies[i],
            numSamples: (sampleRate * 1.5).round(),
            sampleRate: sampleRate,
            detuneCents: detuneCents[i],
            boostHarmonic: i == 0 || i == 5 ? 4 : 0,
            boostAmplitude: i == 0 || i == 5 ? 0.8 : 0.0,
          ),
      ];
      final silence = List<double>.filled((sampleRate * 0.5).round(), 0);
      final references = [
        for (var i = 0; i < standardTuningFrequencies.length; i++)
          standardTuningFrequencies[i] *
              math.pow(2, detuneCents[i] / 1200).toDouble(),
      ];

      final fakeAudio = FakeAudioInputService();
      final service = PitchDetectionService(
        audioInputService: fakeAudio,
        useIsolate: true,
      );
      final errors = <Object>[];
      final emittedFrequencies = <double>[];
      final subscription = service.pitchStream.listen(
        (PitchDetection detection) =>
            emittedFrequencies.add(detection.frequency.value),
        onError: (Object error, StackTrace stackTrace) => errors.add(error),
      );
      addTearDown(subscription.cancel);
      await service.start();

      Future<void> pushChunked(List<double> buffer) async {
        for (var i = 0; i < buffer.length; i += chunkSize) {
          fakeAudio.pushSamples(
            buffer.sublist(i, math.min(i + chunkSize, buffer.length)),
          );
          // Short real-time delay between pushes, like a mic delivery cadence.
          await Future<void>.delayed(const Duration(milliseconds: 11));
        }
      }

      // Strum each string, let it ring, then rest: repeat until 120 s elapse.
      final started = DateTime.now();
      final rssSamples = <int>[];
      var maxBuffered = 0;
      var maxPending = 0;
      var lastRssSample = started;
      final soakDuration = const Duration(seconds: 120);
      while (DateTime.now().difference(started) < soakDuration) {
        for (var i = 0; i < plucks.length; i++) {
          await pushChunked(plucks[i]);
          await pushChunked(silence);
          maxBuffered = math.max(maxBuffered, service.bufferedSampleCount);
          maxPending = math.max(maxPending, service.pendingWorkerCount);
          if (DateTime.now().difference(lastRssSample) >=
              const Duration(seconds: 5)) {
            rssSamples.add(ProcessInfo.currentRss);
            lastRssSample = DateTime.now();
          }
        }
      }

      // Let the isolate flush and the GC settle before final readings.
      await Future<void>.delayed(const Duration(seconds: 2));
      rssSamples.add(ProcessInfo.currentRss);
      final finalBuffered = service.bufferedSampleCount;

      final elapsed = DateTime.now().difference(started);
      expect(elapsed.inSeconds, greaterThanOrEqualTo(120),
          reason: 'soak must run for a full 2 minutes');

      expect(errors, isEmpty,
          reason: 'pitch stream must stay error-free during the soak');

      expect(
        maxBuffered,
        lessThan(service.windowSize * 4),
        reason: 'audio buffer must stay bounded; peak was $maxBuffered '
            'samples (< ${service.windowSize * 4})',
      );

      expect(
        maxPending,
        lessThanOrEqualTo(service.maxPendingWindows),
        reason: 'isolate must not exceed its in-flight window cap '
            '(max $maxPending of ${service.maxPendingWindows})',
      );

      double? rssGrowthMiB;
      if (rssSamples.length >= 9) {
        final third = rssSamples.length ~/ 3;
        final firstThird = [...rssSamples.sublist(0, third)]..sort();
        final lastThird = [
          ...rssSamples.sublist(rssSamples.length - third),
        ]..sort();
        final medianFirst = medianOf(firstThird);
        final medianLast = medianOf(lastThird);
        rssGrowthMiB = (medianLast - medianFirst) / (1024 * 1024);
        expect(
          medianLast - medianFirst,
          lessThan(32 * 1024 * 1024),
          reason: 'RSS must not grow by more than 32 MiB over a 2-minute '
              'soak (growth was ${rssGrowthMiB.toStringAsFixed(2)} MiB)',
        );
      }

      // Every open string must have been identified during the soak.
      final detected = emittedFrequencies.toSet();
      for (var i = 0; i < references.length; i++) {
        final reference = references[i];
        final minDiff = detected.fold<double>(
          double.infinity,
          (best, f) => math.min(best, (f - reference).abs()),
        );
        expect(
          minDiff,
          closeTo(0, 3),
          reason: 'string ${i + 1} (~${reference.toStringAsFixed(2)} Hz) was '
              'never detected within 3 Hz (closest emitted value was '
              '${minDiff.toStringAsFixed(2)} Hz away)',
        );
      }

      // Informational metrics for reference/cross-checks.
      // ignore: avoid_print
      print('soak: detections=${emittedFrequencies.length} '
          'maxBuffered=$maxBuffered maxPending=$maxPending '
          'finalBuffered=$finalBuffered '
          'rssGrowthMiB=${rssGrowthMiB?.toStringAsFixed(2) ?? 'n/a'}');

      await service.dispose();
    },
    timeout: const Timeout(Duration(minutes: 4)),
    skip: !_runSoak
        ? '2-minute soak; run with: '
            'flutter test --tags soak --dart-define=RUN_SOAK=true'
        : false,
  );
}

/// Median of an already-sorted list of integers.
double medianOf(List<int> sorted) {
  final mid = sorted.length ~/ 2;
  if (sorted.length.isEven) {
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }
  return sorted[mid].toDouble();
}