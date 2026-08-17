import 'package:flutter_test/flutter_test.dart';
import 'package:linos/domain/models/note.dart';
import 'package:linos/domain/models/tuning.dart';
import 'package:linos/domain/models/tuning_status.dart';
import 'package:linos/domain/use_cases/string_matcher.dart';

void main() {
  final matcher = StringMatcher();

  group('StringMatcher.identify - fundamentals', () {
    test('identifies low E string at its fundamental', () {
      final match = matcher.identify(82.41);
      expect(match, isNotNull);
      expect(match!.stringIndex, 0);
      expect(match.targetNote.label, 'E2');
      expect(match.harmonic, 1);
      expect(match.centsOffset, closeTo(0, 0.01));
      expect(match.status, TuningStatus.inTune);
    });

    test('flat low E is identified as E2 with negative cents', () {
      final match = matcher.identify(82.0);
      expect(match!.stringIndex, 0);
      expect(match.harmonic, 1);
      expect(match.centsOffset, closeTo(-8.6, 0.1));
      expect(match.status, TuningStatus.flat);
    });

    test('sharp low E is identified as E2 with positive cents', () {
      final match = matcher.identify(83.0);
      expect(match!.stringIndex, 0);
      expect(match.harmonic, 1);
      expect(match.centsOffset, closeTo(12.4, 0.1));
      expect(match.status, TuningStatus.sharp);
    });

    test('identifies the A string', () {
      final match = matcher.identify(110.0);
      expect(match!.stringIndex, 1);
      expect(match.harmonic, 1);
      expect(match.centsOffset, closeTo(0, 0.01));
      expect(match.status, TuningStatus.inTune);
    });

    test('identifies the D string', () {
      final match = matcher.identify(146.83);
      expect(match!.stringIndex, 2);
      expect(match.harmonic, 1);
      expect(match.centsOffset, closeTo(0, 0.01));
    });

    test('identifies the G string', () {
      final match = matcher.identify(196.0);
      expect(match!.stringIndex, 3);
      expect(match.harmonic, 1);
      expect(match.centsOffset, closeTo(0, 0.01));
    });

    test('identifies the B string', () {
      final match = matcher.identify(246.94);
      expect(match!.stringIndex, 4);
      expect(match.harmonic, 1);
      expect(match.centsOffset, closeTo(0, 0.01));
    });

    test('identifies the high E string', () {
      final match = matcher.identify(329.63);
      expect(match!.stringIndex, 5);
      expect(match.harmonic, 1);
      expect(match.centsOffset, closeTo(0, 0.01));
      expect(match.status, TuningStatus.inTune);
    });
  });

  group('StringMatcher.identify - significantly out of tune', () {
    test('low E detuned 2 semitones flat is still E2', () {
      final match = matcher.identify(73.42);
      expect(match!.stringIndex, 0);
      expect(match.centsOffset, closeTo(-200, 0.1));
      expect(match.status, TuningStatus.flat);
    });

    test('low E detuned 1 semitone sharp is still E2', () {
      final match = matcher.identify(87.31);
      expect(match!.stringIndex, 0);
      expect(match.centsOffset, closeTo(100, 0.1));
      expect(match.status, TuningStatus.sharp);
    });

    test('A string detuned down to G2 is still A2', () {
      final match = matcher.identify(98.0);
      expect(match!.stringIndex, 1);
      expect(match.centsOffset, closeTo(-200, 0.1));
      expect(match.status, TuningStatus.flat);
    });
  });

  group('StringMatcher.identify - harmonic folding', () {
    test('2nd harmonic of E2 resolves to E2 at harmonic 2', () {
      final match = matcher.identify(164.82);
      expect(match!.stringIndex, 0);
      expect(match.harmonic, 2);
      expect(match.centsOffset, closeTo(0, 0.01));
      expect(match.status, TuningStatus.inTune);
    });

    test('2nd harmonic of A2 resolves to A2 at harmonic 2', () {
      final match = matcher.identify(220.0);
      expect(match!.stringIndex, 1);
      expect(match.harmonic, 2);
      expect(match.centsOffset, closeTo(0, 0.01));
      expect(match.status, TuningStatus.inTune);
    });

    test('3rd harmonic of E2 resolves to E2, not B3 fundamental', () {
      final match = matcher.identify(247.23);
      expect(match!.stringIndex, 0);
      expect(match.harmonic, 3);
      expect(match.centsOffset, closeTo(0, 0.01));
      expect(match.status, TuningStatus.inTune);
    });

    test('3rd harmonic of D3 resolves to D3 at harmonic 3', () {
      final match = matcher.identify(440.49);
      expect(match!.stringIndex, 2);
      expect(match.harmonic, 3);
      expect(match.centsOffset, closeTo(0, 0.01));
      expect(match.status, TuningStatus.inTune);
    });
  });

  group('StringMatcher.identify - threshold and guards', () {
    test('maxMatchCents keeps a close match', () {
      final match = matcher.identify(82.41, maxMatchCents: 50);
      expect(match!.stringIndex, 0);
    });

    test('maxMatchCents rejects a distant match', () {
      expect(matcher.identify(130.0, maxMatchCents: 50), isNull);
    });

    test('returns null for non-positive frequencies', () {
      expect(matcher.identify(0), isNull);
      expect(matcher.identify(-5), isNull);
    });

    test('maxHarmonic 1 disables harmonic folding', () {
      final noFolding = StringMatcher(maxHarmonic: 1);
      final match = noFolding.identify(164.82);
      expect(match, isNotNull);
      expect(match!.harmonic, 1);
      expect(match.stringIndex, 2);
      expect(match.centsOffset, closeTo(200.09, 0.1));
    });
  });

  group('StringMatcher.analyzeForString', () {
    test('returns an in-tune reading for an exactly tuned string', () {
      final state = matcher.analyzeForString(0, 82.41);
      expect(state.targetNote.label, 'E2');
      expect(state.detectedFrequency, 82.41);
      expect(state.centsOffset, closeTo(0, 0.01));
      expect(state.status, TuningStatus.inTune);
      expect(state.hasReading, isTrue);
    });

    test('returns flat for a flat string', () {
      final state = matcher.analyzeForString(0, 82.0);
      expect(state.centsOffset, closeTo(-8.6, 0.1));
      expect(state.status, TuningStatus.flat);
    });

    test('returns sharp for a sharp string', () {
      final state = matcher.analyzeForString(1, 116.0);
      expect(state.centsOffset, closeTo(91.95, 0.1));
      expect(state.status, TuningStatus.sharp);
    });

    test('returns in-tune for the high E string', () {
      final state = matcher.analyzeForString(5, 329.63);
      expect(state.status, TuningStatus.inTune);
      expect(state.centsOffset, closeTo(0, 0.01));
    });

    test('throws for an out-of-range string index', () {
      expect(() => matcher.analyzeForString(-1, 82.41), throwsArgumentError);
      expect(() => matcher.analyzeForString(6, 82.41), throwsArgumentError);
    });

    test('non-positive frequency produces a target-note-only state', () {
      final state = matcher.analyzeForString(0, 0);
      expect(state.targetNote.label, 'E2');
      expect(state.hasReading, isFalse);
      expect(state.detectedFrequency, isNull);
      expect(state.centsOffset, isNull);
    });
  });

  group('StringMatcher.analyzeAll', () {
    test('returns a state for every string in standard tuning', () {
      final states = matcher.analyzeAll(110.0);
      expect(states.length, 6);
      expect(states[0].targetNote.label, 'E2');
      expect(states[5].targetNote.label, 'E4');
      expect(states[1].centsOffset, closeTo(0, 0.01));
      expect(states[1].status, TuningStatus.inTune);
      expect(states[0].centsOffset, closeTo(499.93, 0.1));
      expect(states[0].status, TuningStatus.sharp);
    });
  });

  group('StringMatcher.identifyString', () {
    test('returns an in-tune match for the exact target frequency', () {
      final match = matcher.identifyString(0, 82.41);
      expect(match.stringIndex, 0);
      expect(match.targetNote.label, 'E2');
      expect(match.harmonic, 1);
      expect(match.centsOffset, closeTo(0, 0.01));
      expect(match.status, TuningStatus.inTune);
    });

    test('reports a flat offset for a flat string', () {
      final match = matcher.identifyString(1, 100.0);
      expect(match.stringIndex, 1);
      expect(match.targetNote.label, 'A2');
      expect(match.centsOffset, closeTo(-165.0, 0.1));
      expect(match.status, TuningStatus.flat);
    });

    test('reports a sharp offset for a sharp string', () {
      final match = matcher.identifyString(5, 340.0);
      expect(match.stringIndex, 5);
      expect(match.targetNote.label, 'E4');
      expect(match.centsOffset, closeTo(53.62, 0.1));
      expect(match.status, TuningStatus.sharp);
    });

    test('does not jump strings when detuned beyond ambiguity', () {
      final match = matcher.identifyString(0, 70.0);
      expect(match.stringIndex, 0);
      expect(match.targetNote.label, 'E2');
      expect(match.centsOffset, closeTo(-282.56, 0.1));
    });

    test('throws for an out-of-range string index', () {
      expect(() => matcher.identifyString(-1, 82.41), throwsArgumentError);
      expect(() => matcher.identifyString(6, 82.41), throwsArgumentError);
    });
  });

  group('StringMatcher with a retuned reference pitch', () {
    final matcher442 = StringMatcher(tuning: Tuning.standard.retunedTo(442));

    test('A2 target moves up with A4=442', () {
      final match = matcher442.identifyString(1, 110.5);
      expect(match.stringIndex, 1);
      expect(match.targetNote.label, 'A2');
      expect(match.centsOffset, closeTo(0, 0.1));
      expect(match.status, TuningStatus.inTune);
    });

    test('110.0 at A4=442 reads slightly flat', () {
      final match = matcher442.identifyString(1, 110.0);
      expect(match.centsOffset, closeTo(-7.85, 0.1));
      expect(match.status, TuningStatus.flat);
    });
  });

  group('StringMatcher with a custom tuning', () {
    const dropD = Tuning(
      name: 'Drop D',
      notes: [
        Note(name: 'D', octave: 2, frequency: 73.42),
        Note(name: 'A', octave: 2, frequency: 110.0),
        Note(name: 'D', octave: 3, frequency: 146.83),
        Note(name: 'G', octave: 3, frequency: 196.0),
        Note(name: 'B', octave: 3, frequency: 246.94),
        Note(name: 'E', octave: 4, frequency: 329.63),
      ],
    );
    final dropDMatcher = StringMatcher(tuning: dropD);

    test('identifies low D at its fundamental', () {
      final match = dropDMatcher.identify(73.42);
      expect(match!.stringIndex, 0);
      expect(match.targetNote.label, 'D2');
      expect(match.harmonic, 1);
      expect(match.centsOffset, closeTo(0, 0.01));
      expect(match.status, TuningStatus.inTune);
    });

    test('identifies 82.41 as D2 detuned sharp', () {
      final match = dropDMatcher.identify(82.41);
      expect(match!.stringIndex, 0);
      expect(match.targetNote.label, 'D2');
      expect(match.centsOffset, closeTo(199.98, 0.1));
      expect(match.status, TuningStatus.sharp);
    });
  });
}