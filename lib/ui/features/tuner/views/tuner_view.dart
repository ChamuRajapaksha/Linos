import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../domain/models/pitch_detection.dart';
import '../../../../domain/models/tuning_status.dart';
import '../../../../domain/use_cases/string_matcher.dart';
import '../view_models/tuner_view_model.dart';

class TunerView extends StatefulWidget {
  const TunerView({super.key, required this.viewModel});

  final TunerViewModel viewModel;

  @override
  State<TunerView> createState() => _TunerViewState();
}

class _TunerViewState extends State<TunerView> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.initialize());
  }

  @override
  void dispose() {
    unawaited(widget.viewModel.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ListenableBuilder(
              listenable: widget.viewModel,
              builder: (context, _) {
                return switch (widget.viewModel.state) {
                  TunerViewState.loading => _buildLoading(context),
                  TunerViewState.recording => _buildRecording(context),
                  TunerViewState.permissionRequired => _buildPermission(
                      context,
                      title: 'Microphone access is needed to tune your guitar',
                      buttonLabel: 'Enable Microphone',
                      onPressed: widget.viewModel.requestPermission,
                    ),
                  TunerViewState.permissionDenied => _buildPermission(
                      context,
                      title: 'Microphone access was denied',
                      buttonLabel: 'Enable Microphone',
                      onPressed: widget.viewModel.requestPermission,
                      hint: 'Tap the button to try again.',
                    ),
                  TunerViewState.permissionPermanentlyDenied =>
                    _buildPermission(
                      context,
                      title: 'Microphone access is turned off',
                      message:
                          'Enable it in your device settings to use the tuner.',
                      buttonLabel: 'Open Settings',
                      onPressed: _openAppSettings,
                    ),
                  TunerViewState.error => _buildError(context),
                };
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
  }

  Widget _buildLoading(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Branding(),
        const SizedBox(height: 40),
        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(height: 16),
        Text('Starting…', style: theme.textTheme.labelMedium),
      ],
    );
  }

  Widget _buildRecording(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double level = widget.viewModel.level;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Branding(),
          const SizedBox(height: 32),
          const _TunerGauge(),
          const SizedBox(height: 28),
          SizedBox(
            width: 220,
            child: Row(
              children: [
                Expanded(child: _LevelBar(level: level)),
                const SizedBox(width: 12),
                Text(
                  'LEVEL ${(level * 100).round()}%',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            _DebugPitchReadout(
              pitch: widget.viewModel.pitch,
              stringMatch: widget.viewModel.stringMatch,
            ),
          ],
          const SizedBox(height: 24),
          const _StringRow(),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic_none, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('Listening…', style: theme.textTheme.labelMedium),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermission(
    BuildContext context, {
    required String title,
    required String buttonLabel,
    required VoidCallback onPressed,
    String? message,
    String? hint,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Branding(),
        const SizedBox(height: 40),
        Icon(Icons.mic_off, size: 44, color: scheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium
              ?.copyWith(color: scheme.onSurface),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(onPressed: onPressed, child: Text(buttonLabel)),
        if (hint != null) ...[
          const SizedBox(height: 12),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium,
          ),
        ],
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Branding(),
        const SizedBox(height: 40),
        Icon(Icons.error_outline, size: 44, color: scheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(
          'Something went wrong',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurface),
        ),
        if (widget.viewModel.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.viewModel.errorMessage!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => unawaited(widget.viewModel.initialize()),
          child: const Text('Try Again'),
        ),
      ],
    );
  }
}

class _Branding extends StatelessWidget {
  const _Branding();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('LINOS', style: theme.textTheme.displaySmall),
        const SizedBox(height: 4),
        Text(
          'GUITAR TUNER',
          style: theme.textTheme.labelLarge
              ?.copyWith(color: scheme.primary, letterSpacing: 4),
        ),
      ],
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: level.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Container(
          height: 8,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                color: Color.lerp(
                  scheme.primary.withValues(alpha: 0.35),
                  scheme.primary,
                  value,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      },
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

class _DebugPitchReadout extends StatelessWidget {
  const _DebugPitchReadout({required this.pitch, required this.stringMatch});

  final PitchDetection? pitch;
  final StringMatch? stringMatch;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final PitchDetection? pitch = this.pitch;
    final StringMatch? stringMatch = this.stringMatch;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'DEBUG PITCH',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          if (pitch == null)
            Text('No pitch detected', style: theme.textTheme.labelMedium)
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(pitch.note.label, style: theme.textTheme.titleMedium),
                    const SizedBox(width: 12),
                    Text(
                      '${pitch.frequency.value.toStringAsFixed(1)} Hz  '
                      '${pitch.centsOffset >= 0 ? '+' : ''}'
                      '${pitch.centsOffset.toStringAsFixed(1)} ¢  '
                      'conf ${(pitch.confidence * 100).round()}%',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
                if (stringMatch != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${stringMatch.targetNote.label} · '
                        '${stringMatch.status.label}',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${stringMatch.centsOffset >= 0 ? '+' : ''}'
                        '${stringMatch.centsOffset.toStringAsFixed(1)} ¢',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _statusColor(stringMatch.status),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Color _statusColor(TuningStatus status) {
    switch (status) {
      case TuningStatus.inTune:
        return Colors.green;
      case TuningStatus.flat:
      case TuningStatus.sharp:
        return Colors.orange;
    }
  }
}
