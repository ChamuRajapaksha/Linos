import 'package:flutter_test/flutter_test.dart';
import 'package:linos/domain/use_cases/level_calculator.dart';

void main() {
  group('computeRmsLevel', () {
    test('returns 0 for an empty list', () {
      expect(computeRmsLevel(<double>[]), 0);
    });

    test('returns 0 for silence', () {
      expect(computeRmsLevel([0, 0, 0, 0]), 0);
    });

    test('returns 1.0 for full-scale constant samples', () {
      expect(computeRmsLevel([1, 1, 1, 1]), 1.0);
    });

    test('returns 1.0 for full-scale sine samples', () {
      expect(computeRmsLevel([1, -1, 1, -1, 1, -1]), 1.0);
    });

    test('returns 0.5 for half-scale constant samples', () {
      expect(computeRmsLevel([0.5, 0.5, 0.5, 0.5]), 0.5);
    });

    test('clamps values above 1.0 to 1.0', () {
      expect(computeRmsLevel([2, 0, 2, 0]), 1.0);
      expect(computeRmsLevel([1.5, -1.5]), 1.0);
    });

    test('returns 0.7071 for a half-scale sine', () {
      expect(computeRmsLevel([0.5, 0, -0.5, 0]), closeTo(0.3536, 0.0001));
    });
  });
}