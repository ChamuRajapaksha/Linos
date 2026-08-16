import 'dart:math' as math;

class Frequency {
  const Frequency({required this.value});

  final double value;

  double centsBetween(Frequency other) {
    if (value <= 0 || other.value <= 0) {
      throw ArgumentError('Frequencies must be greater than zero.');
    }
    return 1200 * math.log(value / other.value) / math.ln2;
  }

  @override
  bool operator ==(Object other) {
    return other is Frequency && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}
