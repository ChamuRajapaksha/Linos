import 'package:flutter/material.dart';

class LinosPalette {
  const LinosPalette({
    required this.background,
    required this.panel,
    required this.panelBorder,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.inTune,
    required this.flat,
    required this.sharp,
  });

  final Color background;
  final Color panel;
  final Color panelBorder;
  final Color text;
  final Color textMuted;
  final Color accent;
  final Color onAccent;
  final Color inTune;
  final Color flat;
  final Color sharp;

  static const LinosPalette dark = LinosPalette(
    background: Color(0xFF15110C),
    panel: Color(0xFF1E1913),
    panelBorder: Color(0xFF30281F),
    text: Color(0xFFF0E7D8),
    textMuted: Color(0xFFA2947E),
    accent: Color(0xFFD29A3C),
    onAccent: Color(0xFF211A0E),
    inTune: Color(0xFF43B27C),
    flat: Color(0xFF7FA7C7),
    sharp: Color(0xFFE08A4A),
  );

  static const LinosPalette light = LinosPalette(
    background: Color(0xFFF5F0E6),
    panel: Color(0xFFECE4D6),
    panelBorder: Color(0xFFD9CFBC),
    text: Color(0xFF241D13),
    textMuted: Color(0xFF6E6353),
    accent: Color(0xFFA8721E),
    onAccent: Color(0xFFFAF5EA),
    inTune: Color(0xFF2E7D55),
    flat: Color(0xFF4A7BA3),
    sharp: Color(0xFFB95C2A),
  );

  static LinosPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  Color forStatus(TuningStatusColor status) {
    switch (status) {
      case TuningStatusColor.flat:
        return flat;
      case TuningStatusColor.inTune:
        return inTune;
      case TuningStatusColor.sharp:
        return sharp;
    }
  }
}

enum TuningStatusColor { flat, inTune, sharp }