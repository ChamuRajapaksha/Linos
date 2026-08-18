import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/repositories/pitch_detector.dart';
import 'package:linos/data/repositories/yin_pitch_detector.dart';

import '../../helpers/guitar_signal.dart';
import '../../helpers/wav_reader.dart';

/// Runs YIN against real recordings dropped into test/fixtures/guitar.
///
/// Naming convention: `<stringNumber>-<detuneCents>.wav`, e.g. `1-0.wav`
/// (string 1 = low E, 82.41 Hz). See test/fixtures/guitar/README.md for the
/// recording procedure. Skips automatically when no `.wav` fixtures exist.
void main() {
  const fixtureDir = 'test/fixtures/guitar';
  final dir = Directory(fixtureDir);
  final wavFiles = dir.existsSync()
      ? dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.wav'))
          .toList()
      : <File>[];

  group('real guitar corpus', () {
    test(
      'detects fundamentals from recorded WAV fixtures',
      () {
        const config = PitchDetectorConfig();
        final detector = YinPitchDetector(config: config);
        final namePattern = RegExp(r'^(\d)-([+-]?\d+)\.wav$');

        for (final file in wavFiles) {
          final name = file.uri.pathSegments.last;
          final match = namePattern.firstMatch(name);
          expect(
            match,
            isNotNull,
            reason: 'fixture "$name" must match <stringNumber>-<detuneCents>.wav',
          );
          final stringIndex = int.parse(match!.group(1)!) - 1;
          expect(
            stringIndex,
            inInclusiveRange(0, 5),
            reason: 'fixture "$name" string number out of range',
          );
          final detune = double.parse(match.group(2)!);
          final f0 = standardTuningFrequencies[stringIndex];
          final expected = f0 * math.pow(2, detune / 1200);

          final samples = readPcm16Wav(file.readAsBytesSync());
          expect(samples, isNotNull, reason: 'could not parse "$name"');
          expect(
            samples!.length,
            greaterThanOrEqualTo(config.windowSize),
            reason: '"$name" too short for a detection window',
          );
          final start = math.min(
            config.sampleRate ~/ 2,
            samples.length - config.windowSize,
          );
          final window = samples.sublist(start, start + config.windowSize);
          final result = detector.detect(window);
          expect(result, isNotNull, reason: 'no detection for "$name"');
          final error =
              1200 * math.log(result!.frequency.value / expected) / math.ln2;
          expect(
            error.abs(),
            lessThan(10.0),
            reason: '"$name": detected ${result.frequency.value} Hz, '
                'expected $expected Hz (${error.toStringAsFixed(2)} cents)',
          );
        }
      },
      skip: wavFiles.isEmpty
          ? 'no .wav fixtures in test/fixtures/guitar (see README)'
          : false,
    );
  });
}