import 'package:get_it/get_it.dart';

import '../data/repositories/custom_tuning_store.dart';
import '../data/repositories/last_tuning_store.dart';
import '../data/repositories/tuning_repository.dart';
import '../data/services/audio_input_service.dart';
import '../data/services/pitch_detection_service.dart';
import '../data/services/record_audio_input_service.dart';
import '../domain/use_cases/string_matcher.dart';
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
          // YIN on a compute isolate keeps the UI thread free during detection.
          useIsolate: true,
        ),
      );
    }
    if (!locator.isRegistered<StringMatcher>()) {
      locator.registerLazySingleton<StringMatcher>(StringMatcher.new);
    }
    if (!locator.isRegistered<CustomTuningStore>()) {
      locator.registerLazySingleton<CustomTuningStore>(
        SharedPreferencesCustomTuningStore.new,
      );
    }
    if (!locator.isRegistered<TuningRepository>()) {
      locator.registerLazySingleton<TuningRepository>(
        () => TuningRepository(
          customTuningStore: locator<CustomTuningStore>(),
        ),
      );
    }
    if (!locator.isRegistered<LastTuningStore>()) {
      locator.registerLazySingleton<LastTuningStore>(
        SharedPreferencesLastTuningStore.new,
      );
    }
    if (!locator.isRegistered<TunerViewModel>()) {
      locator.registerLazySingleton<TunerViewModel>(
        () => TunerViewModel(
          audioInputService: locator<AudioInputService>(),
          pitchDetectionService: locator<PitchDetectionService>(),
          stringMatcher: locator<StringMatcher>(),
          tuningRepository: locator<TuningRepository>(),
          lastTuningStore: locator<LastTuningStore>(),
        ),
      );
    }
  }
}