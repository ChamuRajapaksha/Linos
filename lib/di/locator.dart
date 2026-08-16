import 'package:get_it/get_it.dart';

import '../ui/features/tuner/view_models/tuner_view_model.dart';

final GetIt locator = GetIt.instance;

abstract final class Locator {
  static void init() {
    if (!locator.isRegistered<TunerViewModel>()) {
      locator.registerLazySingleton<TunerViewModel>(TunerViewModel.new);
    }
  }
}