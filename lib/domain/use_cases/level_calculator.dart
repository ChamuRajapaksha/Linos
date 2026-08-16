import 'dart:math';

double computeRmsLevel(List<double> samples) {
  if (samples.isEmpty) {
    return 0;
  }
  var sumOfSquares = 0.0;
  for (final sample in samples) {
    sumOfSquares += sample * sample;
  }
  final rms = sqrt(sumOfSquares / samples.length);
  return rms.clamp(0.0, 1.0);
}