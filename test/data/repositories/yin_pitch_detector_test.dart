import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/repositories/pitch_detector.dart';
import 'package:linos/data/repositories/yin_pitch_detector.dart';

import '../../helpers/guitar_signal.dart';

List<double> generateSine(
  double frequency,
  int numSamples,
  int sampleRate, {
  double amplitude = 0.5,
  double phase = 0.0,
}) {
  final samples = List<double>.filled(numSamples, 0);
  for (var i = 0; i < numSamples; i++) {
    samples[i] =
        amplitude * math.sin(2 * math.pi * frequency * i / sampleRate + phase);
  }
  return samples;
}

double centsFrom(double detected, double expected) {
  return 1200 * math.log(detected / expected) / math.ln2;
}

/// Unit tests for the YIN pitch detector on sines and the guitar corpus.
void main() {
  const config = PitchDetectorConfig();

  group('YinPitchDetector', () {
    test('detects pure sine fundamentals within 5 cents across phases', () {
      final detector = YinPitchDetector(config: config);
      const frequencies = [
        82.41, 110.0, 146.83, 196.0, 246.94, 329.63, 440.0, 523.25, 880.0,
      ];
      const phases = [0.0, 0.73, 2.31];

      for (final phase in phases) {
        for (final frequency in frequencies) {
          final samples = generateSine(
            frequency,
            config.windowSize,
            config.sampleRate,
            phase: phase,
          );
          final result = detector.detect(samples);
          expect(
            result,
            isNotNull,
            reason: 'no detection for $frequency Hz, phase $phase',
          );
          expect(
            result!.frequency.value,
            closeTo(frequency, 1.0),
            reason: '$frequency Hz, phase $phase',
          );
          expect(
            centsFrom(result.frequency.value, frequency).abs(),
            lessThan(5.0),
            reason: '$frequency Hz, phase $phase',
          );
          expect(result.confidence, greaterThan(config.minConfidence));
          expect(result.rms, greaterThan(0.1));
          expect(result.snrDb, greaterThan(config.minSnrDb));
        }
      }
    });

    test('returns null for silence', () {
      final detector = YinPitchDetector(config: config);
      final silence = List<double>.filled(config.windowSize, 0);
      expect(detector.detect(silence), isNull);
    });

    test('returns null for very quiet noise', () {
      final detector = YinPitchDetector(config: config);
      final rng = math.Random(7);
      final quiet = List<double>.generate(
        config.windowSize,
        (_) => (rng.nextDouble() * 2 - 1) * 0.005,
      );
      expect(detector.detect(quiet), isNull);
    });

    test('returns null for pure white noise', () {
      final detector = YinPitchDetector(config: config);
      final rng = math.Random(7);
      final noise = List<double>.generate(
        config.windowSize,
        (_) => rng.nextDouble() * 2 - 1,
      );
      expect(detector.detect(noise), isNull);
    });

    group('guitar corpus (octave-error regression)', () {
      test('open strings in-tune return the fundamental', () {
        final detector = YinPitchDetector(config: config);
        for (var i = 0; i < standardTuningFrequencies.length; i++) {
          final f0 = standardTuningFrequencies[i];
          final samples = generatePluckedString(
            frequency: f0,
            numSamples: config.windowSize,
            sampleRate: config.sampleRate,
          );
          final result = detector.detect(samples);
          expect(result, isNotNull, reason: 'string ${i + 1} ($f0 Hz)');
          final error = centsFrom(result!.frequency.value, f0);
          expect(
            error.abs(),
            lessThan(4.0),
            reason: 'string ${i + 1}: detected ${result.frequency.value} '
                'for f0=$f0 (${error.toStringAsFixed(2)} cents)',
          );
        }
      });

      test('open strings detuned +-50 cents are tracked', () {
        final detector = YinPitchDetector(config: config);
        for (final detune in [-50.0, 50.0]) {
          for (var i = 0; i < standardTuningFrequencies.length; i++) {
            final f0 = standardTuningFrequencies[i];
            final expected = f0 * math.pow(2, detune / 1200);
            final samples = generatePluckedString(
              frequency: f0,
              numSamples: config.windowSize,
              sampleRate: config.sampleRate,
              detuneCents: detune,
            );
            final result = detector.detect(samples);
            expect(
              result,
              isNotNull,
              reason: 'string ${i + 1} detune $detune',
            );
            final error = centsFrom(result!.frequency.value, expected);
            expect(
              error.abs(),
              lessThan(4.0),
              reason: 'string ${i + 1} detune $detune: detected '
                  '${result.frequency.value} for ${expected.toStringAsFixed(2)} '
                  '(${error.toStringAsFixed(2)} cents)',
            );
          }
        }
      });

      test('boosted harmonics (weak fundamental) still resolve the fundamental',
          () {
        final detector = YinPitchDetector(config: config);
        for (final boost in [2, 4]) {
          for (var i = 0; i < standardTuningFrequencies.length; i++) {
            final f0 = standardTuningFrequencies[i];
            final samples = generatePluckedString(
              frequency: f0,
              numSamples: config.windowSize,
              sampleRate: config.sampleRate,
              boostHarmonic: boost,
              boostAmplitude: 1.5,
            );
            final result = detector.detect(samples);
            expect(
              result,
              isNotNull,
              reason: 'string ${i + 1} boost=$boost',
            );
            final error = centsFrom(result!.frequency.value, f0);
            expect(
              error.abs(),
              lessThan(5.0),
              reason: 'string ${i + 1} boost=$boost: detected '
                  '${result.frequency.value} for f0=$f0 '
                  '(${error.toStringAsFixed(2)} cents)',
            );
          }
        }
      });
    });

    test('detect throws for wrong sample count', () {
      final detector = YinPitchDetector(config: config);
      expect(
        () => detector.detect(List<double>.filled(config.windowSize - 1, 0)),
        throwsArgumentError,
      );
      expect(
        () => detector.detect(List<double>.filled(config.windowSize + 1, 0)),
        throwsArgumentError,
      );
    });

    test('rejects invalid config', () {
      expect(
        () => YinPitchDetector(
          config: const PitchDetectorConfig(windowSize: 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => YinPitchDetector(
          config: const PitchDetectorConfig(minSnrDb: -1),
        ),
        throwsArgumentError,
      );
    });
  });
}