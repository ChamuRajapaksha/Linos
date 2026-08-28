import '../models/frequency.dart';
import '../models/note.dart';
import '../models/string_state.dart';
import '../models/tuning.dart';
import '../models/tuning_status.dart';
import 'tuning_status_classifier.dart';

class StringMatch {
  const StringMatch({
    required this.stringIndex,
    required this.targetNote,
    required this.centsOffset,
    required this.harmonic,
    required this.status,
  });

  final int stringIndex;
  final Note targetNote;
  final double centsOffset;
  final int harmonic;
  final TuningStatus status;

  @override
  bool operator ==(Object other) {
    return other is StringMatch &&
        other.stringIndex == stringIndex &&
        other.targetNote == targetNote &&
        other.centsOffset == centsOffset &&
        other.harmonic == harmonic &&
        other.status == status;
  }

  @override
  int get hashCode =>
      Object.hash(stringIndex, targetNote, centsOffset, harmonic, status);
}

/// Matches detected frequencies to a string in the tuning, folding harmonic
/// partials back to their fundamental. Folds up to the 4th harmonic (the
/// default `maxHarmonic`) so, for example, a low-E reading captured at its
/// 4th partial still resolves to the correct string.
///
/// A genuine fundamental (harmonic-1) reading is preferred over a coincidental
/// harmonic of a lower string whenever it lands within
/// `fundamentalPreferenceCents`. This is required because harmonic folding is
/// ambiguous across tunings (and even within standard tuning): e.g. low-E's
/// 3rd harmonic (247.23 Hz) sits ~2 cents from B3's fundamental, and in the
/// octave-stacked open tunings a top string's fundamental equals a lower
/// string's 2nd harmonic. Detection (YIN) reports the true fundamental, so the
/// prefer-fundamental rule keeps genuine plucks on the string that was played,
/// only falling back to harmonic folding when the reading is close to no
/// fundamental at all.
class StringMatcher {
  const StringMatcher({
    this.tuning = Tuning.standard,
    this.classifier = const TuningStatusClassifier(),
    this.maxHarmonic = 4,
    this.fundamentalPreferenceCents = 25.0,
  })  : assert(maxHarmonic >= 1),
        assert(fundamentalPreferenceCents >= 0);

  final Tuning tuning;
  final TuningStatusClassifier classifier;
  final int maxHarmonic;

  /// Cents within which a harmonic-1 (fundamental) candidate beats any
  /// harmonic-folded candidate.
  final double fundamentalPreferenceCents;

  StringMatch? identify(double frequency, {double? maxMatchCents}) {
    if (frequency <= 0) {
      return null;
    }
    StringMatch? best;
    StringMatch? bestFundamental;
    for (var i = 0; i < tuning.notes.length; i++) {
      final note = tuning.notes[i];
      for (var h = 1; h <= maxHarmonic; h++) {
        final harmonicFrequency = note.frequency * h;
        final cents = Frequency(value: frequency)
            .centsBetween(Frequency(value: harmonicFrequency));
        final isBetter = best == null ||
            cents.abs() < best.centsOffset.abs() ||
            (cents.abs() == best.centsOffset.abs() &&
                (h < best.harmonic ||
                    (h == best.harmonic && i < best.stringIndex)));
        if (isBetter) {
          best = StringMatch(
            stringIndex: i,
            targetNote: note,
            centsOffset: cents,
            harmonic: h,
            status: classifier.classify(cents),
          );
        }
        if (h == 1 && (bestFundamental == null ||
            cents.abs() < bestFundamental.centsOffset.abs())) {
          bestFundamental = StringMatch(
            stringIndex: i,
            targetNote: note,
            centsOffset: cents,
            harmonic: 1,
            status: classifier.classify(cents),
          );
        }
      }
    }
    final candidate = (bestFundamental != null &&
            bestFundamental.centsOffset.abs() <= fundamentalPreferenceCents)
        ? bestFundamental
        : best;
    if (maxMatchCents != null &&
        candidate != null &&
        candidate.centsOffset.abs() > maxMatchCents) {
      return null;
    }
    return candidate;
  }

  StringState analyzeForString(int stringIndex, double frequency) {
    if (stringIndex < 0 || stringIndex >= tuning.notes.length) {
      throw ArgumentError('stringIndex out of range: $stringIndex');
    }
    final note = tuning.notes[stringIndex];
    if (frequency <= 0) {
      return StringState(targetNote: note);
    }
    final cents = Frequency(value: frequency)
        .centsBetween(Frequency(value: note.frequency));
    return StringState(
      targetNote: note,
      detectedFrequency: frequency,
      centsOffset: cents,
      status: classifier.classify(cents),
    );
  }

  StringMatch identifyString(int stringIndex, double frequency) {
    if (stringIndex < 0 || stringIndex >= tuning.notes.length) {
      throw ArgumentError('stringIndex out of range: $stringIndex');
    }
    final state = analyzeForString(stringIndex, frequency);
    return StringMatch(
      stringIndex: stringIndex,
      targetNote: state.targetNote,
      centsOffset: state.centsOffset ?? 0,
      harmonic: 1,
      status: state.status,
    );
  }

  List<StringState> analyzeAll(double frequency) {
    return [
      for (var i = 0; i < tuning.notes.length; i++)
        analyzeForString(i, frequency),
    ];
  }
}