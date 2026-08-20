import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/repositories/isolate_pitch_detector.dart';
import 'package:linos/data/repositories/pitch_detector.dart';

List<double> sine(double freq, int count, {double amplitude = 0.5}) {
  const int sampleRate = 44100;
  return List<double>.generate(
    count,
    (int i) => amplitude * math.sin(2 * math.pi * freq * i / sampleRate),
  );
}

/// Covers the isolate-backed detector for both YIN and FFT kinds.
void main() {
  const config = PitchDetectorConfig();

  group('IsolatePitchDetector', () {
    for (final kind in DetectorKind.values) {
      test('detects a 440 Hz sine with kind ${kind.name}', () async {
        final detector = IsolatePitchDetector(kind: kind, config: config);

        final result = await detector.detect(sine(440, config.windowSize));
        expect(result, isNotNull);
        expect(result!.frequency.value, closeTo(440, 1.5));

        await detector.dispose();
      });

      test('multiple sequential detects are consistent (${kind.name})',
          () async {
        final detector = IsolatePitchDetector(kind: kind, config: config);

        final results = await Future.wait([
          detector.detect(sine(110, config.windowSize)),
          detector.detect(sine(220, config.windowSize)),
          detector.detect(sine(440, config.windowSize)),
        ]);

        expect(results[0]!.frequency.value, closeTo(110, 1.5));
        expect(results[1]!.frequency.value, closeTo(220, 1.5));
        expect(results[2]!.frequency.value, closeTo(440, 1.5));

        await detector.dispose();
      });
    }

    test('silence resolves to null, not a worker error', () async {
      for (final kind in DetectorKind.values) {
        final detector = IsolatePitchDetector(kind: kind, config: config);

        final result = await detector.detect(
          List<double>.filled(config.windowSize, 0),
        );
        expect(result, isNull, reason: 'gated-out silence is a no-detection');

        await detector.dispose();
      }
    });

    test('pendingCount reflects in-flight detections', () async {
      final detector = IsolatePitchDetector(
        kind: DetectorKind.yin,
        config: config,
      );

      final window = sine(440, config.windowSize);
      final futures = <Future<dynamic>>[
        detector.detect(window),
        detector.detect(window),
        detector.detect(window),
      ];
      expect(detector.pendingCount, 3);

      await Future.wait(futures);
      expect(detector.pendingCount, 0);

      await detector.dispose();
    });

    test('dispose fails pending detections and subsequent detects throw',
        () async {
      final detector = IsolatePitchDetector(
        kind: DetectorKind.yin,
        config: config,
      );

      final window = sine(440, config.windowSize);
      final pending = detector.detect(window);
      final pendingExpectation = expectLater(pending, throwsStateError);
      await detector.dispose();
      await pendingExpectation;

      expect(() => detector.detect(window), throwsStateError);
    });
  });
}