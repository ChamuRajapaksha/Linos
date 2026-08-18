import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/repositories/fft_pitch_detector.dart';
import 'package:linos/data/repositories/pitch_detector.dart';
import 'package:linos/data/repositories/yin_pitch_detector.dart';

import '../../helpers/guitar_signal.dart';

double centsFrom(double detected, double expected) {
  return 1200 * math.log(detected / expected) / math.ln2;
}

class CorpusResult {
  CorpusResult({required this.detected, required this.expected});

  final double? detected;
  final double expected;

  double? get errorCents =>
      detected == null ? null : centsFrom(detected!, expected);

  bool get isOctaveError {
    final error = errorCents;
    return error == null || error.abs() > 500;
  }
}

CorpusResult runCase(
  PitchDetector detector,
  double f0,
  double detuneCents,
  int boostHarmonic,
) {
  final samples = generatePluckedString(
    frequency: f0,
    numSamples: 4096,
    sampleRate: 44100,
    detuneCents: detuneCents,
    boostHarmonic: boostHarmonic,
    boostAmplitude: 1.5,
  );
  return CorpusResult(
    detected: detector.detect(samples)?.frequency.value,
    expected: f0 * math.pow(2, detuneCents / 1200),
  );
}

/// Benchmarks YIN vs FFT+HPS against the synthetic guitar corpus.
void main() {
  const windowSize = 4096;
  const sampleRate = 44100;

  test('YIN wins the harmonic-rich guitar corpus', () {
    final yin = YinPitchDetector(config: const PitchDetectorConfig());
    final hps = FftPitchDetector(
      config: const PitchDetectorConfig(useHps: true),
    );

    final cases = <String, ({double detune, int boost})>{
      'in-tune': (detune: 0, boost: 0),
      'detune -50': (detune: -50, boost: 0),
      'detune +50': (detune: 50, boost: 0),
      'boost 2': (detune: 0, boost: 2),
      'boost 4': (detune: 0, boost: 4),
    };

    final yinPerString = List<List<double>>.generate(6, (_) => []);
    final hpsPerString = List<List<double>>.generate(6, (_) => []);
    var yinOctaveErrors = 0;
    var hpsOctaveErrors = 0;

    for (var i = 0; i < 6; i++) {
      final f0 = standardTuningFrequencies[i];
      for (final entry in cases.entries) {
        final yinResult = runCase(yin, f0, entry.value.detune, entry.value.boost);
        final hpsResult = runCase(hps, f0, entry.value.detune, entry.value.boost);

        if (yinResult.errorCents != null) {
          yinPerString[i].add(yinResult.errorCents!.abs());
        }
        if (hpsResult.errorCents != null) {
          hpsPerString[i].add(hpsResult.errorCents!.abs());
        }
        if (yinResult.isOctaveError) yinOctaveErrors++;
        if (hpsResult.isOctaveError) hpsOctaveErrors++;
      }
    }

    final table = StringBuffer();
    table.writeln(
        '${'string'.padRight(8)} | ${'YIN mean'.padRight(9)} '
        '${'YIN max'.padRight(8)} | ${'HPS mean'.padRight(9)} '
        '${'HPS max'.padRight(8)}');
    for (var i = 0; i < 6; i++) {
      final yinMean = yinPerString[i].isEmpty
          ? double.nan
          : yinPerString[i].reduce((a, b) => a + b) / yinPerString[i].length;
      final yinMax = yinPerString[i].isEmpty ? double.nan : yinPerString[i].reduce(math.max);
      final hpsMean = hpsPerString[i].isEmpty
          ? double.nan
          : hpsPerString[i].reduce((a, b) => a + b) / hpsPerString[i].length;
      final hpsMax = hpsPerString[i].isEmpty ? double.nan : hpsPerString[i].reduce(math.max);
      table.writeln(
        '${(i + 1).toString().padRight(8)} | '
        '${yinMean.toStringAsFixed(2).padLeft(9)} '
        '${yinMax.toStringAsFixed(2).padLeft(8)} | '
        '${hpsMean.toStringAsFixed(2).padLeft(9)} '
        '${hpsMax.toStringAsFixed(2).padLeft(8)}',
      );
    }
    table.writeln('YIN octave errors: $yinOctaveErrors');
    table.writeln('HPS octave errors: $hpsOctaveErrors');
    // ignore: avoid_print
    print(table);

    final yinAll = yinPerString.expand((e) => e).toList();
    final hpsAll = hpsPerString.expand((e) => e).toList();

    expect(yinOctaveErrors, 0, reason: 'YIN must have zero octave errors');
    expect(
      yinAll.reduce(math.max),
      lessThan(15.0),
      reason: 'YIN max abs error must stay under 15 cents',
    );
    expect(hpsOctaveErrors, 0, reason: 'HPS must have zero octave errors');
    expect(
      hpsAll.reduce(math.max),
      lessThan(30.0),
      reason: 'HPS max abs error must stay under 30 cents',
    );
  });

  test('both detectors fit the real-time frame budget', () {
    final yin = YinPitchDetector(config: const PitchDetectorConfig());
    final hps = FftPitchDetector(
      config: const PitchDetectorConfig(useHps: true),
    );
    final samples = generatePluckedString(
      frequency: 110.0,
      numSamples: windowSize,
      sampleRate: sampleRate,
    );

    // hop = windowSize/2 samples => ~46 ms per frame at the default rate.
    final frameBudgetMs = (windowSize ~/ 2) / sampleRate * 1000;

    for (final entry in [
      ('YIN', yin),
      ('FFT+HPS', hps),
    ]) {
      for (var i = 0; i < 10; i++) {
        entry.$2.detect(samples);
      }
      final sw = Stopwatch();
      var bestMicros = 1 << 62;
      for (var i = 0; i < 30; i++) {
        sw
          ..reset()
          ..start();
        entry.$2.detect(samples);
        sw.stop();
        if (sw.elapsedMicroseconds < bestMicros) {
          bestMicros = sw.elapsedMicroseconds;
        }
      }
      final bestMs = bestMicros / 1000;
      // ignore: avoid_print
      print(
        '${entry.$1} best per-frame latency: '
        '${bestMs.toStringAsFixed(2)} ms (budget ${frameBudgetMs.toStringAsFixed(1)} ms)',
      );
      expect(bestMs, lessThan(frameBudgetMs));
    }
  });
}