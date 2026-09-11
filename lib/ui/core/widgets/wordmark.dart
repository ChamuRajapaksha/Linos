import 'package:flutter/material.dart';

import '../theme/linos_palette.dart';

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.label = 'TUNER'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'LINOS',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 5,
            color: palette.text,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: palette.accent,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}