import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../view_models/tuner_view_model.dart';

class TunerView extends StatelessWidget {
  const TunerView({super.key, required this.viewModel});

  final TunerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('LINOS', style: theme.textTheme.displaySmall),
                    const SizedBox(height: 4),
                    Text(
                      'GUITAR TUNER',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: scheme.primary, letterSpacing: 4),
                    ),
                    const SizedBox(height: 48),
                    const _TunerGauge(),
                    const SizedBox(height: 48),
                    const _StringRow(),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mic_none,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Microphone input arrives in the next milestone',
                          style: theme.textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TunerGauge extends StatelessWidget {
  const _TunerGauge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: CustomPaint(painter: _GaugePainter(Theme.of(context).colorScheme)),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.scheme);

  final ColorScheme scheme;

  static const int _tickCount = 21;
  static const double _tickSweepDegrees = 100;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2 - 14;

    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = scheme.primary.withValues(alpha: 0.4);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      (-_tickSweepDegrees / 2) * math.pi / 180,
      _tickSweepDegrees * math.pi / 180,
      false,
      arcPaint,
    );

    final Paint minorTickPaint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = scheme.onSurfaceVariant.withValues(alpha: 0.55);
    final Paint majorTickPaint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = scheme.onSurfaceVariant;

    for (int i = 0; i < _tickCount; i++) {
      final double t = i / (_tickCount - 1);
      final double angle =
          -math.pi / 2 + (t - 0.5) * _tickSweepDegrees * math.pi / 180;
      final bool major = i % 5 == 0;
      final double inner = radius - (major ? 15 : 11);
      final double outer = radius - 2;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        major ? majorTickPaint : minorTickPaint,
      );
    }

    final Paint needlePaint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = scheme.onSurface;
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy - radius + 22),
      needlePaint,
    );

    canvas.drawCircle(center, 5, Paint()..color = scheme.primary);
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.scheme != scheme;
}

class _StringRow extends StatelessWidget {
  const _StringRow();

  static const List<String> _strings = ['E', 'A', 'D', 'G', 'B', 'E'];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < _strings.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Container(
            width: 40,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _strings[i],
                  style: theme.textTheme.labelLarge
                      ?.copyWith(letterSpacing: 1, color: scheme.onSurface),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 2,
                  width: 20,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}