import 'package:flutter/services.dart';

/// Central access point for tactile feedback across the app.
///
/// Keeps haptics behind one seam so behaviors can be tuned or disabled in a
/// single place.
abstract final class Haptics {
  /// A light tick, e.g. when auto-detection locks onto a string.
  static Future<void> stringDetected() => HapticFeedback.lightImpact();

  /// A light tick, e.g. when the user manually selects a string.
  static Future<void> stringSelected() => HapticFeedback.selectionClick();

  /// A light confirmation, e.g. selecting a search result or chord.
  static Future<void> selectionTap() => HapticFeedback.lightImpact();

  /// A stronger confirmation, e.g. when a string comes into tune.
  static Future<void> inTune() => HapticFeedback.mediumImpact();
}
