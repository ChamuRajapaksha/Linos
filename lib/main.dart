import 'package:flutter/material.dart';

import 'di/locator.dart';
import 'ui/core/linos_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Locator.init();
  runApp(const LinosApp());
}