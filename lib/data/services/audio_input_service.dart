abstract class AudioInputService {
  Future<bool> requestMicrophonePermission();
  Stream<List<double>> get audioSamples;
}