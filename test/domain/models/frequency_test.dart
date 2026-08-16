import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/domain/models/frequency.dart';

void main() {
  group('Frequency', () {
    test('centsBetween is 0 for identical frequencies', () {
      const f = Frequency(value: 440.0);
      expect(f.centsBetween(const Frequency(value: 440.0)), 0);
    });

    test('centsBetween is 1200 for one octave up', () {
      const f = Frequency(value: 440.0);
      expect(f.centsBetween(const Frequency(value: 220.0)), closeTo(1200, 0.001));
    });

    test('centsBetween is -1200 for one octave down', () {
      const f = Frequency(value: 440.0);
      expect(f.centsBetween(const Frequency(value: 880.0)), closeTo(-1200, 0.001));
    });

    test('centsBetween is ~100 for a semitone', () {
      const f = Frequency(value: 440.0);
      final semitoneRatio = math.pow(2, 1 / 12).toDouble();
      expect(f.centsBetween(Frequency(value: 440.0 / semitoneRatio)),
          closeTo(100, 0.001));
    });

    test('centsBetween is ~25.085 per cent ratio direction sanity', () {
      const f = Frequency(value: 440.0);
      expect(f.centsBetween(const Frequency(value: 400.0)),
          closeTo(165.004, 0.01));
    });

    test('centsBetween throws ArgumentError on non-positive input', () {
      const f = Frequency(value: 440.0);
      expect(() => f.centsBetween(const Frequency(value: 0)), throwsArgumentError);
      expect(() => f.centsBetween(const Frequency(value: -100)),
          throwsArgumentError);
      const invalid = Frequency(value: 0);
      expect(() => invalid.centsBetween(const Frequency(value: 440)),
          throwsArgumentError);
    });

    test('equality compares value', () {
      const f = Frequency(value: 440.0);
      expect(f, const Frequency(value: 440.0));
      expect(f == const Frequency(value: 441.0), isFalse);
      expect(f.hashCode, const Frequency(value: 440.0).hashCode);
    });
  });
}