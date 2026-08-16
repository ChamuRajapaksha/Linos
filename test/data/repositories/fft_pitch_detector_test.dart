import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/models/detected_frequency.dart';
import 'package:linos/data/repositories/fft_pitch_detector.dart';
import 'package:linos/data/repositories/pitch_detector.dart';
import 'package:linos/domain/models/frequency.dart';

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

void main() {
  const config = PitchDetectorConfig();

  group('FftPitchDetector', () {
    test('detects known frequencies within 1.0 Hz across phases', () {
      final detector = FftPitchDetector(config: config);
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
          expect(result.confidence, greaterThan(config.minConfidence));
          expect(result.rms, greaterThan(0.1));
        }
      }
    });

    test('returns null for silence', () {
      final detector = FftPitchDetector(config: config);
      final silence = List<double>.filled(config.windowSize, 0);
      expect(detector.detect(silence), isNull);
    });

    test('returns null for very quiet noise', () {
      final detector = FftPitchDetector(config: config);
      final rng = math.Random(7);
      final quiet = List<double>.generate(
        config.windowSize,
        (_) => (rng.nextDouble() * 2 - 1) * 0.005,
      );
      expect(detector.detect(quiet), isNull);
    });

    test('rejects non-power-of-two fftSize', () {
      expect(
        () => FftPitchDetector(
          config: const PitchDetectorConfig(fftSize: 3000),
        ),
        throwsArgumentError,
      );
    });

    test('rejects fftSize smaller than windowSize', () {
      expect(
        () => FftPitchDetector(
          config: const PitchDetectorConfig(fftSize: 2048),
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid config ranges', () {
      expect(
        () => FftPitchDetector(
          config: const PitchDetectorConfig(windowSize: 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => FftPitchDetector(
          config: const PitchDetectorConfig(maxFrequency: 24000),
        ),
        throwsArgumentError,
      );
      expect(
        () => FftPitchDetector(
          config: const PitchDetectorConfig(minFrequency: 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => FftPitchDetector(
          config: const PitchDetectorConfig(minConfidence: 1.5),
        ),
        throwsArgumentError,
      );
    });

    test('detect throws for wrong sample count', () {
      final detector = FftPitchDetector(config: config);
      expect(
        () => detector.detect(List<double>.filled(config.windowSize - 1, 0)),
        throwsArgumentError,
      );
      expect(
        () => detector.detect(List<double>.filled(config.windowSize + 1, 0)),
        throwsArgumentError,
      );
    });
  });

  group('magnitudeSpectrum', () {
    test('DC signal peaks at bin 0', () {
      const fftSize = 256;
      final spectrum =
          FftPitchDetector.magnitudeSpectrum(List<double>.filled(fftSize, 1), fftSize);
      expect(spectrum[0], closeTo(fftSize, 1e-6));
      for (var i = 1; i < spectrum.length; i++) {
        expect(spectrum[i], lessThan(1e-6));
      }
    });

    test('sine peaks at the expected bin', () {
      const fftSize = 8192;
      const sampleRate = 44100;
      final samples = generateSine(440.0, fftSize, sampleRate);
      final spectrum = FftPitchDetector.magnitudeSpectrum(samples, fftSize);
      var peakBin = 0;
      var peak = spectrum[0];
      for (var i = 1; i < spectrum.length; i++) {
        if (spectrum[i] > peak) {
          peak = spectrum[i];
          peakBin = i;
        }
      }
      final expectedBin = 440.0 * fftSize / sampleRate;
      expect(peakBin, anyOf((expectedBin - 1).floor(), (expectedBin + 1).floor()));
    });

    test('rejects invalid fftSize and oversized samples', () {
      expect(
        () => FftPitchDetector.magnitudeSpectrum(const [0.0], 3000),
        throwsArgumentError,
      );
      expect(
        () => FftPitchDetector.magnitudeSpectrum(List<double>.filled(9, 0), 8),
        throwsArgumentError,
      );
    });
  });

  group('DetectedFrequency', () {
    test('equality compares all fields', () {
      const a = DetectedFrequency(
        frequency: Frequency(value: 440.0),
        confidence: 0.9,
        rms: 0.1,
      );
      const b = DetectedFrequency(
        frequency: Frequency(value: 440.0),
        confidence: 0.9,
        rms: 0.1,
      );
      const c = DetectedFrequency(
        frequency: Frequency(value: 441.0),
        confidence: 0.9,
        rms: 0.1,
      );
      expect(a, b);
      expect(a == c, isFalse);
      expect(a.hashCode, b.hashCode);
    });
  });
}
