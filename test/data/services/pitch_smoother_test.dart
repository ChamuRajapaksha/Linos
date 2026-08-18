import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/models/detected_frequency.dart';
import 'package:linos/data/services/pitch_smoother.dart';
import 'package:linos/domain/models/frequency.dart';

DetectedFrequency d(
  double f, {
  double confidence = 1.0,
  double rms = 0.5,
  double snrDb = 20.0,
}) {
  return DetectedFrequency(
    frequency: Frequency(value: f),
    confidence: confidence,
    rms: rms,
    snrDb: snrDb,
  );
}

/// Locks the smoother onto [f] using [lockOnFrames] consistent detections.
PitchSmoother lockOnto(
  double f, {
  int lockOnFrames = 3,
  int lockOffFrames = 2,
  double maxLockCents = 40,
  double switchThresholdCents = 60,
  double emaAlpha = 0.35,
  double minConfidenceToHold = 0.1,
  int maxHeldFrames = 15,
}) {
  final smoother = PitchSmoother(
    lockOnFrames: lockOnFrames,
    lockOffFrames: lockOffFrames,
    maxLockCents: maxLockCents,
    switchThresholdCents: switchThresholdCents,
    emaAlpha: emaAlpha,
    minConfidenceToHold: minConfidenceToHold,
    maxHeldFrames: maxHeldFrames,
  );
  for (var i = 0; i < lockOnFrames; i++) {
    smoother.process(d(f));
  }
  return smoother;
}

/// Covers PitchSmoother lock-on, lock-off, EMA, and silence hold.
void main() {
  group('PitchSmoother lock-on', () {
    test('emits nothing until lockOnFrames consistent frames, then the value',
        () {
      final smoother = PitchSmoother();

      expect(smoother.isLocked, isFalse);
      expect(smoother.process(d(440)), isNull);
      expect(smoother.process(d(440)), isNull);

      final locked = smoother.process(d(440));
      expect(locked, isNotNull);
      expect(locked!.frequency, closeTo(440, 0.001));
      expect(locked.confidence, 1.0);
      expect(locked.rms, 0.5);
      expect(locked.snrDb, 20.0);
      expect(smoother.isLocked, isTrue);
    });

    test('an outlier between consistent frames does not break lock-on', () {
      final smoother = PitchSmoother();

      smoother.process(d(440));
      smoother.process(d(440));
      expect(smoother.process(d(900)), isNull); // replaces the candidate
      smoother.process(d(440));
      smoother.process(d(440));

      final locked = smoother.process(d(440));
      expect(locked, isNotNull);
      expect(locked!.frequency, closeTo(440, 0.001));
    });
  });

  group('PitchSmoother while locked', () {
    test('a single outlier holds the current value and does not switch', () {
      final smoother = lockOnto(440);

      final held = smoother.process(d(880));
      expect(held!.frequency, closeTo(440, 0.001));

      // Returning in-tune cancels the pending switch.
      final back = smoother.process(d(440));
      expect(back!.frequency, closeTo(440, 0.001));
      expect(smoother.isLocked, isTrue);
    });

    test('an octave flip for lockOffFrames consistent frames switches', () {
      final smoother = lockOnto(440);

      final first = smoother.process(d(880));
      expect(first!.frequency, closeTo(440, 0.001)); // held, no move

      final second = smoother.process(d(880));
      expect(second!.frequency, closeTo(880, 0.001)); // switch completes
      expect(smoother.isLocked, isTrue);
    });

    test('a guard-band outlier holds the current value without switching', () {
      final smoother = lockOnto(440);

      // ~49 cents off (within the 40..60 guard band).
      final outlier = d(440 * math.pow(2, 49 / 1200).toDouble());
      final held = smoother.process(outlier);
      expect(held!.frequency, closeTo(440, 0.001));

      // Still locked on 440 afterwards.
      final next = smoother.process(d(440));
      expect(next!.frequency, closeTo(440, 0.001));
    });

    test('gradual detune drift is tracked by the EMA', () {
      final smoother = lockOnto(440);
      double? emitted;

      for (var k = 1; k <= 30; k++) {
        final cents = 2.0 * k;
        final freq = 440 * math.pow(2, cents / 1200).toDouble();
        emitted = smoother.process(d(freq))!.frequency;
      }

      final finalTarget = 440 * math.pow(2, 60 / 1200).toDouble();
      expect(emitted, closeTo(finalTarget, 3.0));
      expect(emitted, greaterThan(450));
    });

    test('low-confidence frames barely nudge the value', () {
      final highConf = lockOnto(440);
      final highConfResult = highConf.process(d(445, confidence: 1.0));
      // alpha = 0.35 * (0.5 + 0.5*1.0) = 0.35 -> 440 + 0.35*5 = 441.75
      expect(highConfResult!.frequency, closeTo(441.75, 0.01));

      final lowConf = lockOnto(440);
      final lowConfResult = lowConf.process(d(445, confidence: 0.05));
      // alpha = 0.35 * 0.525 * 0.25 ~= 0.0459 -> ~440.23
      expect(lowConfResult!.frequency, closeTo(440.23, 0.05));

      expect(
        (lowConfResult.frequency - 440).abs(),
        lessThan((highConfResult.frequency - 440).abs()),
      );
    });
  });

  group('PitchSmoother silence and reset', () {
    test('noDetection after maxHeldFrames resets the lock', () {
      final smoother = lockOnto(440);

      for (var i = 0; i < 16; i++) {
        smoother.noDetection();
      }
      expect(smoother.isLocked, isFalse);

      // A later stable candidate locks again from scratch.
      expect(smoother.process(d(440)), isNull);
      expect(smoother.process(d(440)), isNull);
      final relocked = smoother.process(d(440));
      expect(relocked, isNotNull);
      expect(relocked!.frequency, closeTo(440, 0.001));
    });

    test('reset clears all state', () {
      final smoother = lockOnto(440);
      expect(smoother.isLocked, isTrue);

      smoother.reset();
      expect(smoother.isLocked, isFalse);
      expect(smoother.process(d(440)), isNull);
    });
  });

  group('PitchSmoother median locking', () {
    test('odd candidate set locks on the median', () {
      final smoother = PitchSmoother();
      smoother.process(d(440));
      smoother.process(d(441));
      final locked = smoother.process(d(439));
      expect(locked!.frequency, closeTo(440, 0.001));
    });

    test('even candidate set locks on the average of the two middle values',
        () {
      final smoother = PitchSmoother(lockOnFrames: 4);
      smoother.process(d(440));
      smoother.process(d(441));
      smoother.process(d(439));
      final locked = smoother.process(d(443));
      expect(locked!.frequency, closeTo(440.5, 0.001));
    });
  });
}