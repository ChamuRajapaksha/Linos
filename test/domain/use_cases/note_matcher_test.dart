import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/domain/models/frequency.dart';
import 'package:linos/domain/use_cases/note_matcher.dart';

void main() {
  const matcher = NoteMatcher();

  group('NoteMatcher', () {
    test('matches A4 at 440.0 Hz with 0 cents', () {
      final match = matcher.match(const Frequency(value: 440.0));
      expect(match.note.label, 'A4');
      expect(match.midiNumber, 69);
      expect(match.centsOffset, closeTo(0, 0.01));
    });

    test('matches E2 at 82.41 Hz', () {
      final match = matcher.match(const Frequency(value: 82.41));
      expect(match.note.label, 'E2');
      expect(match.midiNumber, 40);
      expect(match.centsOffset, closeTo(0, 0.5));
    });

    test('matches A2 at 110.0 Hz with 0 cents', () {
      final match = matcher.match(const Frequency(value: 110.0));
      expect(match.note.label, 'A2');
      expect(match.midiNumber, 45);
      expect(match.centsOffset, closeTo(0, 0.01));
    });

    test('matches E4 at 329.63 Hz', () {
      final match = matcher.match(const Frequency(value: 329.63));
      expect(match.note.label, 'E4');
      expect(match.midiNumber, 64);
      expect(match.centsOffset, closeTo(0, 0.5));
    });

    test('matches A#4 at 466.16 Hz with ~0 cents', () {
      final match = matcher.match(const Frequency(value: 466.16));
      expect(match.note.label, 'A#4');
      expect(match.midiNumber, 70);
      expect(match.centsOffset, closeTo(0, 0.5));
    });

    test('matches A4 at 435.0 Hz about 19.79 cents flat', () {
      final match = matcher.match(const Frequency(value: 435.0));
      expect(match.note.label, 'A4');
      expect(match.centsOffset, closeTo(-19.79, 0.1));
    });

    test('matches A4 at 445.0 Hz about 19.56 cents sharp', () {
      final match = matcher.match(const Frequency(value: 445.0));
      expect(match.note.label, 'A4');
      expect(match.centsOffset, closeTo(19.56, 0.1));
    });

    test('matches D#5 at its exact frequency', () {
      final match = matcher.match(const Frequency(value: 622.25));
      expect(match.note.label, 'D#5');
      expect(match.midiNumber, 75);
      expect(match.centsOffset, closeTo(0, 0.5));
    });

    test('snaps just below the boundary to D#5 with about +50 cents', () {
      final match = matcher.match(const Frequency(value: 640.4));
      expect(match.note.label, 'D#5');
      expect(match.midiNumber, 75);
      expect(match.centsOffset, closeTo(50, 1.0));
    });

    test('snaps just above the boundary to E5 with about -50 cents', () {
      final match = matcher.match(const Frequency(value: 640.6));
      expect(match.note.label, 'E5');
      expect(match.midiNumber, 76);
      expect(match.centsOffset, closeTo(-50, 1.0));
    });

    test('midiNumber stays consistent for random frequencies', () {
      final rng = math.Random(42);
      for (var i = 0; i < 200; i++) {
        final frequency = Frequency(value: 30 + rng.nextDouble() * 970);
        final match = matcher.match(frequency);
        expect(match.note.midiNumber, match.midiNumber);
        expect(match.centsOffset.abs(), lessThanOrEqualTo(50.01));
      }
    });

    test('supports a custom A4 reference', () {
      const matcher442 = NoteMatcher(a4Reference: 442.0);
      final match = matcher442.match(const Frequency(value: 442.0));
      expect(match.note.label, 'A4');
      expect(match.midiNumber, 69);
      expect(match.centsOffset, closeTo(0, 0.01));
    });
  });
}
