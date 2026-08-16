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

class StringMatcher {
  const StringMatcher({
    this.tuning = Tuning.standard,
    this.classifier = const TuningStatusClassifier(),
    this.maxHarmonic = 3,
  }) : assert(maxHarmonic >= 1);

  final Tuning tuning;
  final TuningStatusClassifier classifier;
  final int maxHarmonic;

  StringMatch? identify(double frequency, {double? maxMatchCents}) {
    if (frequency <= 0) {
      return null;
    }
    StringMatch? best;
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
      }
    }
    if (maxMatchCents != null &&
        best != null &&
        best.centsOffset.abs() > maxMatchCents) {
      return null;
    }
    return best;
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

  List<StringState> analyzeAll(double frequency) {
    return [
      for (var i = 0; i < tuning.notes.length; i++)
        analyzeForString(i, frequency),
    ];
  }
}