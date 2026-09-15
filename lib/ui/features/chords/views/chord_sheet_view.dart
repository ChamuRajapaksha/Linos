import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/haptics/haptic_feedback.dart';
import '../../../core/theme/linos_palette.dart';
import '../../chords/view_models/chord_sheet_view_model.dart';
import '../../../../domain/models/chord_sheet.dart';
import '../../../../domain/models/song.dart';
import 'chord_diagram_sheet.dart';

/// Displays the chord sheet for a [Song].
class ChordSheetView extends StatefulWidget {
  const ChordSheetView({
    super.key,
    required this.song,
    required this.viewModel,
  });

  final Song song;
  final ChordSheetViewModel viewModel;

  @override
  State<ChordSheetView> createState() => _ChordSheetViewState();
}

class _ChordSheetViewState extends State<ChordSheetView>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _scrollController.addListener(_onScroll);
    unawaited(widget.viewModel.load(widget.song));
  }

  @override
  void dispose() {
    if (widget.viewModel.isAutoscrolling) {
      widget.viewModel.stopAutoscroll();
    }
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions || !position.hasPixels) return;
    final double max = position.maxScrollExtent;
    final double progress = max > 0
        ? (position.pixels / max).clamp(0.0, 1.0).toDouble()
        : 0;
    widget.viewModel.setProgress(progress);
  }

  // ignore: unused_element
  void _handlePlayPause() {
    if (widget.viewModel.isAutoscrolling) {
      widget.viewModel.stopAutoscroll();
      _ticker.stop();
    } else if (MediaQuery.disableAnimationsOf(context)) {
      if (_scrollController.hasClients) {
        final position = _scrollController.position;
        if (position.hasContentDimensions &&
            position.hasPixels &&
            position.maxScrollExtent > 0) {
          _scrollController.jumpTo(position.maxScrollExtent);
        }
      }
    } else {
      widget.viewModel.startAutoscroll();
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final Duration dt = elapsed - _lastTick;
    _lastTick = elapsed;
    if (dt == Duration.zero || !widget.viewModel.isAutoscrolling) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    if (position.isScrollingNotifier.value) return;
    final double seconds = dt.inMicroseconds / Duration.microsecondsPerSecond;
    final double target =
        position.pixels + widget.viewModel.autoscrollSpeedPx * seconds;
    if (target >= position.maxScrollExtent) {
      _ticker.stop();
      widget.viewModel.stopAutoscroll();
      _scrollController.jumpTo(position.maxScrollExtent);
    } else {
      position.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final ThemeData theme = Theme.of(context);
        final LinosPalette palette = LinosPalette.forBrightness(
          theme.brightness,
        );
        final ChordSheet? sheet = widget.viewModel.sheet;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: palette.panel,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_back, color: palette.text),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.song.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: palette.text,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  widget.song.artist,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sheet?.key != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: palette.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: palette.accent.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            widget.viewModel.transposedKey!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: palette.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _TransposeStepper(
                        viewModel: widget.viewModel,
                        palette: palette,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: switch (widget.viewModel.state) {
              ChordSheetViewState.loading => const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
              ChordSheetViewState.error => _ErrorView(
                message: widget.viewModel.errorMessage,
                onRetry: () => unawaited(widget.viewModel.load(widget.song)),
              ),
              ChordSheetViewState.ready => _SheetContent(
                sheet: sheet!,
                palette: palette,
                theme: theme,
                onChordTap: widget.viewModel.selectChord,
                transposedChord: widget.viewModel.transposedChord,
                scrollController: _scrollController,
              ),
              _ => const SizedBox.shrink(),
            },
          ),
        );
      },
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
            Icon(Icons.error_outline, size: 44, color: palette.textMuted),
            const SizedBox(height: 16),
            Text(
              "Couldn't load chord sheet.",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: palette.text),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _SheetContent extends StatelessWidget {
  const _SheetContent({
    required this.sheet,
    required this.palette,
    required this.theme,
    required this.onChordTap,
    required this.transposedChord,
    required this.scrollController,
  });

  final ChordSheet sheet;
  final LinosPalette palette;
  final ThemeData theme;
  final ValueChanged<String?> onChordTap;
  final String Function(String) transposedChord;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16).copyWith(
        bottom: 96,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in sheet.lines)
            if (line is SongSection)
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Text(
                  line.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: palette.accent,
                    letterSpacing: 2,
                  ),
                ),
              )
            else if (line is LyricLine)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final wc in line.words)
                        _WordChordColumn(
                          wordChord: wc,
                          palette: palette,
                          theme: theme,
                          onTap: onChordTap,
                          transposedChord: transposedChord,
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _WordChordColumn extends StatelessWidget {
  const _WordChordColumn({
    required this.wordChord,
    required this.palette,
    required this.theme,
    required this.onTap,
    required this.transposedChord,
  });

  final WordChord wordChord;
  final LinosPalette palette;
  final ThemeData theme;
  final ValueChanged<String?> onTap;
  final String Function(String) transposedChord;

  @override
  Widget build(BuildContext context) {
    final String? chord = wordChord.chord;
    final String? display = chord == null ? null : transposedChord(chord);
    return GestureDetector(
      onTap: () {
        if (display != null) {
          unawaited(showChordDiagram(context, chordName: display));
        }
        onTap(display);
        unawaited(Haptics.selectionTap());
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (chord != null)
              Text(
                display!,
                semanticsLabel: display,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.accent,
                ),
              )
            else
              const SizedBox(height: 14),
            const SizedBox(height: 2),
            Text(
              wordChord.word,
              style: TextStyle(fontSize: 14, color: palette.text, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransposeStepper extends StatelessWidget {
  const _TransposeStepper({
    required this.viewModel,
    required this.palette,
    required this.theme,
  });

  final ChordSheetViewModel viewModel;
  final LinosPalette palette;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final int transposition = viewModel.transposition;
    final bool canLower = transposition > ChordSheetViewModel.minTransposition;
    final bool canRaise = transposition < ChordSheetViewModel.maxTransposition;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: canLower
                ? () {
                    viewModel.transposeDown();
                    unawaited(Haptics.selectionTap());
                  }
                : null,
            icon: const Icon(Icons.remove, size: 18),
            color: palette.accent,
            disabledColor: palette.textMuted,
            tooltip: 'Transpose down',
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          Semantics(
            label: 'Reset transposition',
            button: true,
            child: GestureDetector(
              onTap: () {
                if (transposition != 0) {
                  viewModel.resetTransposition();
                  unawaited(Haptics.selectionTap());
                }
              },
              child: Tooltip(
                message: 'Reset transposition',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    transposition > 0 ? '+$transposition' : '$transposition',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: transposition == 0
                          ? palette.textMuted
                          : palette.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: canRaise
                ? () {
                    viewModel.transposeUp();
                    unawaited(Haptics.selectionTap());
                  }
                : null,
            icon: const Icon(Icons.add, size: 18),
            color: palette.accent,
            disabledColor: palette.textMuted,
            tooltip: 'Transpose up',
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
