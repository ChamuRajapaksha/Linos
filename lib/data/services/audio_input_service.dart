enum MicrophonePermissionState { unknown, granted, denied, permanentlyDenied, restricted }

abstract class AudioInputService {
  Future<MicrophonePermissionState> checkPermission();
  Future<MicrophonePermissionState> requestPermission();
  Future<void> start();
  Future<void> stop();
  Stream<List<double>> get audioSamples;
}
