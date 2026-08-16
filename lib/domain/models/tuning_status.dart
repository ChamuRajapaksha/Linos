enum TuningStatus {
  flat('FLAT'),
  inTune('IN TUNE'),
  sharp('SHARP');

  const TuningStatus(this.label);

  final String label;
}
