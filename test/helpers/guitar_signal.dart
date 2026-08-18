import 'dart:math' as math;

/// The 6 open-string fundamentals of standard tuning (string 1 = low E).
const List<double> standardTuningFrequencies = [
  82.41, 110.0, 146.83, 196.0, 246.94, 329.63,
];

/// Generates a deterministic synthetic guitar pluck.
///
/// Model: `harmonicCount` harmonics with amplitude `~1/h^harmonicRolloff`,
/// slight inharmonicity (real strings are not perfectly harmonic), and an
/// exponential decay that is faster for higher harmonics. A 5 ms linear
/// attack ramp is applied to the total signal, then white noise is added.
/// The result is clipped to [-1, 1].
List<double> generatePluckedString({
  required double frequency,
  required int numSamples,
  required int sampleRate,
  double amplitude = 0.6,
  int harmonicCount = 12,
  double harmonicRolloff = 1.5,
  double decayTimeSeconds = 1.2,
  // Typical for plain steel guitar strings; keeps the effective pitch of the
  // synthesized tone within ~2.5 cents of the requested fundamental.
  double inharmonicity = 0.00005,
  double detuneCents = 0.0,
  double noiseFloor = 0.002,
  int boostHarmonic = 0,
  double boostAmplitude = 0.0,
  int seed = 42,
}) {
  final rng = math.Random(seed);
  final f0 = frequency * math.pow(2, detuneCents / 1200).toDouble();
  final attackSamples = math.min(numSamples, (sampleRate * 0.005).round());

  final phases = List<double>.filled(harmonicCount, 0);
  for (var h = 0; h < harmonicCount; h++) {
    phases[h] = rng.nextDouble() * 2 * math.pi;
  }

  final samples = List<double>.filled(numSamples, 0);
  for (var i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    final attack = i < attackSamples ? i / attackSamples : 1.0;
    var value = 0.0;
    for (var h = 1; h <= harmonicCount; h++) {
      final amp = amplitude * math.pow(h, -harmonicRolloff);
      final hAmp = h == boostHarmonic ? amp * boostAmplitude : amp;
      final freq = h * f0 * (1 + inharmonicity * h * h);
      final tauH = decayTimeSeconds * math.pow(h, -0.5);
      value += hAmp *
          math.exp(-t / tauH) *
          math.sin(2 * math.pi * freq * t + phases[h - 1]);
    }
    final noise = noiseFloor * (rng.nextDouble() - 0.5);
    samples[i] = (value * attack + noise).clamp(-1.0, 1.0);
  }
  return samples;
}