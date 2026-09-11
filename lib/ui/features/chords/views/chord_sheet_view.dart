import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/haptics/haptic_feedback.dart';
import '../../../core/theme/linos_palette.dart';
import '../../chords/view_models/chord_sheet_view_model.dart';
import '../../../../domain/models/chord_sheet.dart';
import '../../../../domain/models/song.dart';

/// Displays the chord sheet for a [Song].
class ChordSheetView extends StatefulWidget {
  const ChordSheetView({super.key, required this.song, required this.viewModel});

  final Song song;
  final ChordSheetViewModel viewModel;

  @override
  State<ChordSheetView> createState() => _ChordSheetViewState();
}

class _ChordSheetViewState extends State<ChordSheetView> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.load(widget.song));
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
              if (sheet?.key != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Container(
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
                        sheet!.key!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.accent,
                        ),
                      ),
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
                onRetry: () =>
                    unawaited(widget.viewModel.load(widget.song)),
              ),
              ChordSheetViewState.ready => _SheetContent(
                sheet: sheet!,
                palette: palette,
                theme: theme,
                onChordTap: widget.viewModel.selectChord,
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
              style: theme.textTheme.titleMedium?.copyWith(
                color: palette.text,
              ),
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
  });

  final ChordSheet sheet;
  final LinosPalette palette;
  final ThemeData theme;
  final ValueChanged<String?> onChordTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
  });

  final WordChord wordChord;
  final LinosPalette palette;
  final ThemeData theme;
  final ValueChanged<String?> onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap(wordChord.chord);
        Haptics.stringSelected();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (wordChord.chord != null)
              Text(
                wordChord.chord!,
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
              style: TextStyle(
                fontSize: 14,
                color: palette.text,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}