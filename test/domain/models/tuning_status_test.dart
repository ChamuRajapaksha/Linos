import 'package:flutter_test/flutter_test.dart';
import 'package:linos/domain/models/tuning_status.dart';

void main() {
  group('TuningStatus', () {
    test('has the expected values', () {
      expect(TuningStatus.values, [TuningStatus.flat, TuningStatus.inTune, TuningStatus.sharp]);
    });

    test('labels are correct', () {
      expect(TuningStatus.flat.label, 'FLAT');
      expect(TuningStatus.inTune.label, 'IN TUNE');
      expect(TuningStatus.sharp.label, 'SHARP');
    });
  });
}