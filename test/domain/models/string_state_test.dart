import 'package:flutter_test/flutter_test.dart';
import 'package:linos/domain/models/note.dart';
import 'package:linos/domain/models/string_state.dart';
import 'package:linos/domain/models/tuning_status.dart';

void main() {
  const e2 = Note(name: 'E', octave: 2, frequency: 82.41);

  group('StringState', () {
    test('hasReading is false when nothing detected', () {
      const state = StringState(targetNote: e2);
      expect(state.hasReading, isFalse);
      expect(state.detectedFrequency, isNull);
      expect(state.centsOffset, isNull);
    });

    test('hasReading is true when frequency detected', () {
      const state = StringState(
        targetNote: e2,
        detectedFrequency: 82.0,
        centsOffset: -8.64,
        status: TuningStatus.flat,
      );
      expect(state.hasReading, isTrue);
      expect(state.detectedFrequency, 82.0);
      expect(state.centsOffset, -8.64);
      expect(state.status, TuningStatus.flat);
    });

    test('hasReading is true even when centsOffset is null', () {
      const state = StringState(targetNote: e2, detectedFrequency: 82.0);
      expect(state.hasReading, isTrue);
    });

    test('default status is inTune', () {
      const state = StringState(targetNote: e2);
      expect(state.status, TuningStatus.inTune);
    });

    test('copyWith updates fields', () {
      const state = StringState(targetNote: e2);
      final updated = state.copyWith(
        detectedFrequency: 82.0,
        centsOffset: -8.64,
        status: TuningStatus.flat,
      );
      expect(updated.detectedFrequency, 82.0);
      expect(updated.centsOffset, -8.64);
      expect(updated.status, TuningStatus.flat);
      expect(updated.targetNote, e2);
    });

    test('copyWith sets detectedFrequency back to null', () {
      const state = StringState(
        targetNote: e2,
        detectedFrequency: 82.0,
        centsOffset: -8.64,
        status: TuningStatus.flat,
      );
      final cleared = state.copyWith(detectedFrequency: null);
      expect(cleared.detectedFrequency, isNull);
      expect(cleared.hasReading, isFalse);
      expect(cleared.centsOffset, -8.64);
    });

    test('copyWith sets centsOffset back to null', () {
      const state = StringState(
        targetNote: e2,
        detectedFrequency: 82.0,
        centsOffset: -8.64,
        status: TuningStatus.sharp,
      );
      final cleared = state.copyWith(centsOffset: null);
      expect(cleared.centsOffset, isNull);
      expect(cleared.detectedFrequency, 82.0);
      expect(cleared.hasReading, isTrue);
    });

    test('copyWith without arguments preserves everything', () {
      const state = StringState(
        targetNote: e2,
        detectedFrequency: 82.0,
        centsOffset: -8.64,
        status: TuningStatus.flat,
      );
      expect(state.copyWith(), state);
    });

    test('equality compares all fields', () {
      const state = StringState(
        targetNote: e2,
        detectedFrequency: 82.0,
        centsOffset: -8.64,
        status: TuningStatus.flat,
      );
      expect(
        state,
        const StringState(
          targetNote: e2,
          detectedFrequency: 82.0,
          centsOffset: -8.64,
          status: TuningStatus.flat,
        ),
      );
      expect(state == const StringState(targetNote: e2), isFalse);
      expect(state.hashCode, state.copyWith().hashCode);
    });
  });
}