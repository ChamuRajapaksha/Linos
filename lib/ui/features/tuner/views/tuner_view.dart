import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../domain/models/note.dart';
import '../../../../domain/models/pitch_detection.dart';
import '../../../../domain/models/tuning_status.dart';
import '../../../../domain/use_cases/string_matcher.dart';
import '../../../core/theme/linos_palette.dart';
import '../view_models/tuner_view_model.dart';
import 'tuning_picker_sheet.dart';

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
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            return switch (widget.viewModel.state) {
              TunerViewState.loading => const _LoadingView(),
              TunerViewState.recording => _RecordingView(
                  viewModel: widget.viewModel,
                  onOpenSettings: () => _openSettings(context),
                ),
              TunerViewState.permissionRequired => _PermissionView(
                  icon: Icons.mic_none,
                  title: 'Microphone access is needed to tune your guitar',
                  buttonLabel: 'Enable Microphone',
                  onPressed: widget.viewModel.requestPermission,
                  hint: 'Linos listens for the pitch of a plucked string — '
                      'it never records or stores audio.',
                ),
              TunerViewState.permissionDenied => _PermissionView(
                  icon: Icons.mic_off,
                  title: 'Microphone access was denied',
                  buttonLabel: 'Enable Microphone',
                  onPressed: widget.viewModel.requestPermission,
                  hint: 'Tap the button to try again.',
                ),
              TunerViewState.permissionPermanentlyDenied => _PermissionView(
                  icon: Icons.mic_off,
                  title: 'Microphone access is turned off',
                  message: 'Enable it in your device settings to use the tuner.',
                  buttonLabel: 'Open Settings',
                  onPressed: _openAppSettings,
                ),
              TunerViewState.error => _ErrorView(
                  message: widget.viewModel.errorMessage,
                  onRetry: () => unawaited(widget.viewModel.initialize()),
                ),
            };
          },
        ),
      ),
    );
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
  }

  Future<void> _openSettings(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _SettingsSheet(
        viewModel: widget.viewModel,
        onOpenTuningPicker: () => _openTuningPicker(context, widget.viewModel),
      ),
    );
  }

  Future<void> _openTuningPicker(
      BuildContext context, TunerViewModel viewModel) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => TuningPickerSheet(
        presets: viewModel.tuningPresets,
        selectedId: viewModel.tuningId,
        onSelected: viewModel.selectTuning,
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Wordmark(),
          SizedBox(height: 40),
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _RecordingView extends StatelessWidget {
  const _RecordingView({required this.viewModel, required this.onOpenSettings});

  final TunerViewModel viewModel;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);
    final PitchDetection? pitch = viewModel.pitch;
    final StringMatch? match = viewModel.stringMatch;
    final bool hasSignal = pitch != null && match != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TunerHeader(onOpenSettings: onOpenSettings),
          const SizedBox(height: 28),
          _StringRail(
            notes: viewModel.tuningNotes,
            selected: viewModel.selectedString,
            active: match?.stringIndex,
            inTune: match?.status == TuningStatus.inTune,
            onSelect: viewModel.selectString,
          ),
          const SizedBox(height: 30),
          _HeroNote(palette: palette, match: match, pitch: pitch),
          const SizedBox(height: 4),
          _NeedleGauge(
            centsOffset: hasSignal ? match.centsOffset : null,
            status: match?.status,
          ),
          const SizedBox(height: 24),
          _LevelMeter(level: viewModel.level),
          const SizedBox(height: 20),
          _StatusLine(hasSignal: hasSignal),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TunerHeader extends StatelessWidget {
  const _TunerHeader({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);
    return Row(
      children: [
        const _Wordmark(),
        const Spacer(),
        IconButton(
          onPressed: onOpenSettings,
          tooltip: 'Tuner settings',
          icon: Icon(Icons.tune, color: palette.textMuted),
        ),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

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
          'TUNER',
          style: theme.textTheme.labelMedium?.copyWith(
            color: palette.accent,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}

class _StringRail extends StatelessWidget {
  const _StringRail({
    required this.notes,
    required this.selected,
    required this.active,
    required this.inTune,
    required this.onSelect,
  });

  final List<Note> notes;
  final int? selected;
  final int? active;
  final bool inTune;
  final ValueChanged<int?> onSelect;

  static const List<double> _thickness = [5, 4.2, 3.4, 2.8, 2.2, 1.8];
  static const List<String> _ordinal = [
    '6TH',
    '5TH',
    '4TH',
    '3RD',
    '2ND',
    '1ST',
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);
    final Duration duration = _animDuration(context);

    final bool auto = selected == null;

    return Semantics(
      container: true,
      label: auto
          ? 'Auto string detection. Tap a string to focus it.'
          : '${_ordinal[selected!]} string selected. Tap it again for auto detection.',
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.panelBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('STRINGS', style: theme.textTheme.labelMedium),
                const Spacer(),
                AnimatedContainer(
                  duration: duration,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: auto
                        ? palette.accent.withValues(alpha: 0.18)
                        : palette.inTune.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: auto
                          ? palette.accent.withValues(alpha: 0.6)
                          : palette.inTune.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    auto ? 'AUTO' : _ordinal[selected!],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: auto ? palette.accent : palette.inTune,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (int i = 0; i < notes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _StringRailItem(
                      note: notes[i],
                      ordinal: _ordinal[i],
                      thickness: _thickness[i],
                      isSelected: selected == i,
                      isActive: active == i,
                      inTune: inTune && active == i,
                      duration: duration,
                      onTap: () => onSelect(selected == i ? null : i),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StringRailItem extends StatelessWidget {
  const _StringRailItem({
    required this.note,
    required this.ordinal,
    required this.thickness,
    required this.isSelected,
    required this.isActive,
    required this.inTune,
    required this.duration,
    required this.onTap,
  });

  final Note note;
  final String ordinal;
  final double thickness;
  final bool isSelected;
  final bool isActive;
  final bool inTune;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);

    final Color lineColor;
    if (inTune) {
      lineColor = palette.inTune;
    } else if (isActive) {
      lineColor = palette.accent;
    } else if (isSelected) {
      lineColor = palette.accent.withValues(alpha: 0.55);
    } else {
      lineColor = palette.panelBorder;
    }

    final bool lit = isActive || inTune;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$ordinal string, tune to ${note.label}',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: duration,
                width: thickness,
                height: 42,
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(thickness / 2),
                  boxShadow: lit
                      ? [
                          BoxShadow(
                            color: lineColor.withValues(alpha: 0.45),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              AnimatedDefaultTextStyle(
                duration: duration,
                style: theme.textTheme.labelLarge!.copyWith(
                  fontSize: 15,
                  color: isSelected || isActive
                      ? palette.text
                      : palette.textMuted,
                  letterSpacing: 1,
                ),
                child: Text(note.name),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroNote extends StatelessWidget {
  const _HeroNote({
    required this.palette,
    required this.match,
    required this.pitch,
  });

  final LinosPalette palette;
  final StringMatch? match;
  final PitchDetection? pitch;

  static const List<String> _ordinal = ['6TH', '5TH', '4TH', '3RD', '2ND', '1ST'];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasSignal = match != null;

    final String noteName =
        match?.targetNote.name ?? pitch?.note.name ?? (hasSignal ? '' : '—');
    final int? octave = match?.targetNote.octave ?? pitch?.note.octave;

    final StringMatch? localMatch = match;
    final Color heroColor;
    if (localMatch == null) {
      heroColor = palette.textMuted;
    } else {
      heroColor = switch (localMatch.status) {
        TuningStatus.flat => palette.flat,
        TuningStatus.inTune => palette.inTune,
        TuningStatus.sharp => palette.sharp,
      };
    }

    final String caption;
    final String cents;
    final String statusLabel;
    if (localMatch == null) {
      caption = 'AUTO · PLAY A STRING';
      cents = '—';
      statusLabel = 'NO SIGNAL';
    } else {
      final String stringLabel = _ordinal[localMatch.stringIndex];
      final String centsText = localMatch.centsOffset >= 0 ? '+' : '−';
      caption = '$stringLabel STRING · ${localMatch.targetNote.label}';
      cents =
          '$centsText${localMatch.centsOffset.abs().toStringAsFixed(1)}';
      statusLabel = localMatch.status.label;
    }

    return Semantics(
      container: true,
      label: localMatch == null
          ? 'No signal. Play a string to tune.'
          : '${localMatch.targetNote.label}, '
              '${localMatch.status.label.toLowerCase()}, '
              '${localMatch.centsOffset.abs().toStringAsFixed(1)} cents '
              '${localMatch.centsOffset < 0 ? 'flat' : 'sharp'}',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                style: theme.textTheme.displayMedium!.copyWith(
                  fontSize: 96,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -3,
                  height: 1,
                  color: heroColor,
                ),
                child: Text(noteName),
              ),
              if (octave != null) ...[
                const SizedBox(width: 4),
                Text(
                  '$octave',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: palette.textMuted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(caption, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 160),
            style: theme.textTheme.labelLarge!.copyWith(
              fontSize: 15,
              letterSpacing: 1,
              color: match == null ? palette.textMuted : heroColor,
            ),
            child: Text('$cents ¢  ·  $statusLabel'),
          ),
        ],
      ),
    );
  }
}

class _NeedleGauge extends StatelessWidget {
  const _NeedleGauge({this.centsOffset, this.status});

  final double? centsOffset;
  final TuningStatus? status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);
    final Duration duration = _animDuration(context);

    final double target = centsOffset == null ? 0 : centsOffset!.clamp(-50, 50);

    return Semantics(
      container: true,
      label: status == null
          ? 'Needle gauge, no reading'
          : 'Needle ${status!.label.toLowerCase()}, '
              '${centsOffset!.abs().toStringAsFixed(1)} cents',
      excludeSemantics: true,
      child: SizedBox(
        height: 148,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: target),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return CustomPaint(
              painter: _NeedleGaugePainter(
                cents: value,
                status: status,
                palette: palette,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NeedleGaugePainter extends CustomPainter {
  _NeedleGaugePainter({
    required this.cents,
    required this.status,
    required this.palette,
  });

  final double cents;
  final TuningStatus? status;
  final LinosPalette palette;

  static const double _sweepCents = 50;

  double _angleForCents(double c) {
    final double t = (c / _sweepCents).clamp(-1.0, 1.0);
    return -math.pi / 2 + t * (50 * math.pi / 180);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height - 6);
    final double radius = size.height - 10;

    final bool inTune = status == TuningStatus.inTune;
    final bool hasSignal = status != null;

    final Color needleColor;
    if (!hasSignal) {
      needleColor = palette.textMuted;
    } else if (inTune) {
      needleColor = palette.inTune;
    } else if (status == TuningStatus.flat) {
      needleColor = palette.flat;
    } else {
      needleColor = palette.sharp;
    }

    // In-tune band.
    final Paint bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    bandPaint.color = inTune
        ? palette.inTune.withValues(alpha: 0.9)
        : palette.inTune.withValues(alpha: 0.22);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 14),
      _angleForCents(-6),
      12 * math.pi / 180,
      false,
      bandPaint,
    );

    // Base arc.
    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = palette.panelBorder;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _angleForCents(-_sweepCents),
      2 * _sweepCents * math.pi / 180,
      false,
      arcPaint,
    );

    // Ticks every 5 cents, major every 10.
    final Paint minorTick = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = palette.textMuted.withValues(alpha: 0.5);
    final Paint majorTick = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = palette.textMuted;
    final Paint centerTick = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = inTune ? palette.inTune : palette.textMuted;

    for (int c = -_sweepCents.toInt(); c <= _sweepCents.toInt(); c += 5) {
      final double angle = _angleForCents(c.toDouble());
      final bool isCenter = c == 0;
      final bool isMajor = c % 10 == 0;
      final double inner = radius - (isMajor ? 12 : 8);
      final Paint paint = isCenter ? centerTick : (isMajor ? majorTick : minorTick);
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        paint,
      );
    }

    // Needle.
    final Paint needlePaint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = needleColor;
    final double needleAngle = _angleForCents(cents);
    canvas.drawLine(
      center,
      center +
          Offset(math.cos(needleAngle), math.sin(needleAngle)) *
              (radius - 16),
      needlePaint,
    );

    canvas.drawCircle(center, 6, Paint()..color = palette.accent);
    canvas.drawCircle(center, 3, Paint()..color = palette.background);
  }

  @override
  bool shouldRepaint(_NeedleGaugePainter oldDelegate) {
    return oldDelegate.cents != cents ||
        oldDelegate.status != status ||
        oldDelegate.palette != palette;
  }
}

class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: level.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(color: palette.panelBorder),
                          FractionallySizedBox(
                            widthFactor: value,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    palette.accent.withValues(alpha: 0.4),
                                    palette.accent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 74,
          child: Text(
            '${(level * 100).round().toString().padLeft(3, '0')}%',
            textAlign: TextAlign.right,
            style: theme.textTheme.labelMedium!.copyWith(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.hasSignal});

  final bool hasSignal;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          hasSignal ? Icons.mic : Icons.mic_none,
          size: 16,
          color: hasSignal ? palette.accent : palette.textMuted,
        ),
        const SizedBox(width: 8),
        Text(
          hasSignal ? 'Listening…' : 'Play a string to tune',
          style: theme.textTheme.labelMedium,
        ),
      ],
    );
  }
}

class _PermissionView extends StatelessWidget {
  const _PermissionView({
    required this.icon,
    required this.title,
    required this.buttonLabel,
    required this.onPressed,
    this.message,
    this.hint,
  });

  final IconData icon;
  final String title;
  final String buttonLabel;
  final VoidCallback onPressed;
  final String? message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Wordmark(),
            const SizedBox(height: 40),
            Icon(icon, size: 44, color: palette.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: palette.text),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
            if (hint != null) ...[
              const SizedBox(height: 12),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Wordmark(),
            const SizedBox(height: 40),
            Icon(Icons.error_outline, size: 44, color: palette.textMuted),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: palette.text),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.viewModel,
    required this.onOpenTuningPicker,
  });

  final TunerViewModel viewModel;
  final VoidCallback onOpenTuningPicker;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  static const List<double> _options = [438, 440, 442];

  late double _reference = widget.viewModel.a4Reference;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Text('TUNER SETTINGS', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            'All six strings tune to this reference.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          ListenableBuilder(
            listenable: widget.viewModel,
            builder: (_, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'REFERENCE PITCH A4',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    container: true,
                    label:
                        'Reference pitch. ${_reference.toStringAsFixed(0)} hertz.',
                    child: Row(
                      children: [
                        for (int i = 0; i < _options.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: _ChoiceChipButton(
                              label: _options[i].toStringAsFixed(0),
                              selected: _reference == _options[i],
                              onTap: () {
                                setState(() => _reference = _options[i]);
                                widget.viewModel.setReferencePitch(_options[i]);
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    button: true,
                    label:
                        'Choose tuning, currently ${widget.viewModel.tuningName}.',
                    child: InkWell(
                      onTap: widget.onOpenTuningPicker,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: palette.panel,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.panelBorder),
                        ),
                        child: Row(
                          children: [
                            Text('TUNING', style: theme.textTheme.labelMedium),
                            const Spacer(),
                            Flexible(
                              child: Text(
                                '${widget.viewModel.tuningName.toUpperCase()} · ${widget.viewModel.tuningNotes.map((n) => n.name).join('–')}',
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: palette.text,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right,
                                size: 18, color: palette.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              );
            },
          ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  const _ChoiceChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label hertz',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? palette.accent.withValues(alpha: 0.18)
                : palette.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? palette.accent
                  : palette.panelBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge!.copyWith(
              color: selected ? palette.accent : palette.textMuted,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

Duration _animDuration(BuildContext context) {
  return MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 220);
}