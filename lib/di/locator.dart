import 'package:get_it/get_it.dart';

import '../data/services/audio_input_service.dart';
import '../data/services/pitch_detection_service.dart';
import '../data/services/record_audio_input_service.dart';
import '../ui/features/tuner/view_models/tuner_view_model.dart';

final GetIt locator = GetIt.instance;

abstract final class Locator {
  static void init() {
    if (!locator.isRegistered<AudioInputService>()) {
      locator.registerLazySingleton<AudioInputService>(RecordAudioInputService.new);
    }
    if (!locator.isRegistered<PitchDetectionService>()) {
      locator.registerLazySingleton<PitchDetectionService>(
        () => PitchDetectionService(
          audioInputService: locator<AudioInputService>(),
        ),
      );
    }
    if (!locator.isRegistered<TunerViewModel>()) {
      locator.registerLazySingleton<TunerViewModel>(
        () => TunerViewModel(
          audioInputService: locator<AudioInputService>(),
          pitchDetectionService: locator<PitchDetectionService>(),
        ),
      );
    }
  }
}