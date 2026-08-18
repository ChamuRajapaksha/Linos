import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'wav_reader.dart';

/// Covers the PCM16 WAV reader used by the guitar corpus fixtures.
void main() {
  group('readPcm16Wav', () {
    test('round-trips a mono sine through buildPcm16Wav', () {
      const sampleRate = 44100;
      final source = List<double>.generate(
        1024,
        (i) => 0.5 * math.sin(2 * math.pi * 440 * i / sampleRate),
      );
      final bytes = buildPcm16Wav(samples: source, sampleRate: sampleRate);

      final decoded = readPcm16Wav(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.length, source.length);
      for (var i = 0; i < source.length; i++) {
        expect(decoded[i], closeTo(source[i], 1.0 / 32768.0 + 1e-9));
      }
    });

    test('averages stereo channels to mono', () {
      const sampleRate = 8000;
      final left = List<double>.filled(64, 0.5);
      final right = List<double>.filled(64, -0.5);
      final data = ByteData(44 + 64 * 4);
      data.setUint32(0, 0x46464952, Endian.little);
      data.setUint32(4, 36 + 64 * 4, Endian.little);
      data.setUint32(8, 0x45564157, Endian.little);
      data.setUint32(12, 0x20746D66, Endian.little);
      data.setUint32(16, 16, Endian.little);
      data.setUint16(20, 1, Endian.little);
      data.setUint16(22, 2, Endian.little);
      data.setUint32(24, sampleRate, Endian.little);
      data.setUint32(28, sampleRate * 4, Endian.little);
      data.setUint16(32, 4, Endian.little);
      data.setUint16(34, 16, Endian.little);
      data.setUint32(36, 0x61746164, Endian.little);
      data.setUint32(40, 64 * 4, Endian.little);
      var p = 44;
      for (var i = 0; i < 64; i++) {
        data.setInt16(p, (left[i] * 32767).round(), Endian.little);
        data.setInt16(p + 2, (right[i] * 32767).round(), Endian.little);
        p += 4;
      }

      final decoded = readPcm16Wav(data.buffer.asUint8List());
      expect(decoded, isNotNull);
      expect(decoded!.length, 64);
      for (final sample in decoded) {
        expect(sample, closeTo(0.0, 1.0 / 32768.0 + 1e-9));
      }
    });

    test('returns null on malformed headers', () {
      expect(readPcm16Wav(const <int>[]), isNull);
      expect(readPcm16Wav(Uint8List(44)), isNull);
      final notRiff = buildPcm16Wav(samples: [0.0], sampleRate: 8000);
      notRiff[0] = 0x41;
      expect(readPcm16Wav(notRiff), isNull);
    });
  });
}