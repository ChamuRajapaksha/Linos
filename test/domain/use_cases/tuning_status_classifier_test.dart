import 'package:flutter_test/flutter_test.dart';
import 'package:linos/domain/models/tuning_status.dart';
import 'package:linos/domain/use_cases/tuning_status_classifier.dart';

void main() {
  group('TuningStatusClassifier', () {
    const classifier = TuningStatusClassifier();

    test('default tolerance is 5.0', () {
      expect(classifier.inTuneToleranceCents, 5.0);
    });

    test('0 cents is in tune', () {
      expect(classifier.classify(0), TuningStatus.inTune);
    });

    test('within tolerance is in tune', () {
      expect(classifier.classify(4.9), TuningStatus.inTune);
      expect(classifier.classify(-4.9), TuningStatus.inTune);
    });

    test('tolerance boundary is inclusive', () {
      expect(classifier.classify(5.0), TuningStatus.inTune);
      expect(classifier.classify(-5.0), TuningStatus.inTune);
    });

    test('beyond tolerance classifies flat or sharp', () {
      expect(classifier.classify(5.1), TuningStatus.sharp);
      expect(classifier.classify(-5.1), TuningStatus.flat);
      expect(classifier.classify(100), TuningStatus.sharp);
      expect(classifier.classify(-100), TuningStatus.flat);
    });

    test('supports a custom tolerance', () {
      const wide = TuningStatusClassifier(inTuneToleranceCents: 10);
      expect(wide.classify(9), TuningStatus.inTune);
      expect(wide.classify(10), TuningStatus.inTune);
      expect(wide.classify(11), TuningStatus.sharp);
      expect(wide.classify(-11), TuningStatus.flat);
    });
  });
}