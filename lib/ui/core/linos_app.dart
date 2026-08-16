import 'package:flutter/material.dart';

import '../../di/locator.dart';
import '../features/tuner/view_models/tuner_view_model.dart';
import '../features/tuner/views/tuner_view.dart';
import 'theme/app_theme.dart';

class LinosApp extends StatelessWidget {
  const LinosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Linos',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: TunerView(viewModel: locator<TunerViewModel>()),
    );
  }
}