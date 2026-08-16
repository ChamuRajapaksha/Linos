import '../models/tuning_status.dart';

class TuningStatusClassifier {
  const TuningStatusClassifier({this.inTuneToleranceCents = 5.0});

  final double inTuneToleranceCents;

  TuningStatus classify(double centsOffset) {
    if (centsOffset.abs() <= inTuneToleranceCents) {
      return TuningStatus.inTune;
    }
    if (centsOffset < 0) {
      return TuningStatus.flat;
    }
    return TuningStatus.sharp;
  }
}