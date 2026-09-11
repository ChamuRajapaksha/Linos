import 'package:flutter/material.dart';

import '../../../core/haptics/haptic_feedback.dart';
import '../../../core/theme/linos_palette.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../core/widgets/wordmark.dart';
import '../../chords/view_models/song_search_view_model.dart';
import '../../chords/view_models/chord_sheet_view_model.dart';
import '../../chords/views/chord_sheet_view.dart';
import '../../../../data/repositories/chord_sheet_repository.dart';
import '../../../../di/locator.dart';
import '../../../../domain/models/song.dart';

/// Search screen for finding songs by title or artist.
class ChordSearchView extends StatefulWidget {
  const ChordSearchView({super.key, required this.viewModel});

  final SongSearchViewModel viewModel;

  @override
  State<ChordSearchView> createState() => _ChordSearchViewState();
}

class _ChordSearchViewState extends State<ChordSearchView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChipTap(String label) {
    _controller.text = label;
    widget.viewModel.onQueryChanged(label);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: const Wordmark(label: 'CHORDS'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: widget.viewModel.onQueryChanged,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search, color: palette.accent),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _controller.clear();
                            widget.viewModel.clear();
                          },
                          icon: Icon(Icons.clear, color: palette.textMuted),
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.viewModel,
                builder: (context, _) {
                  return switch (widget.viewModel.state) {
                    SongSearchState.idle => _IdleView(
                      onChipTap: _onChipTap,
                    ),
                    SongSearchState.loading => const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                    SongSearchState.results => _ResultsList(
                      results: widget.viewModel.results,
                      onSelect: (song) {
                        widget.viewModel.selectSong(song);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChordSheetView(
                              viewModel: ChordSheetViewModel(
                                repository: locator<ChordSheetRepository>(),
                              ),
                              song: song,
                            ),
                          ),
                        );
                      },
                    ),
                    SongSearchState.empty => _EmptyView(),
                    SongSearchState.error => _ErrorView(
                      message: widget.viewModel.errorMessage,
                      onRetry: () =>
                          widget.viewModel.onQueryChanged(widget.viewModel.query),
                    ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({required this.onChipTap});

  final ValueChanged<String> onChipTap;

  static const List<String> _popular = [
    'Wonderwall',
    'Radioactive',
    'Creep',
    'Imagine',
    'Yesterday',
  ];

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
            Text(
              'Search by title or artist',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'POPULAR',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final label in _popular)
                  _PopularChip(label: label, onTap: () => onChipTap(label)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularChip extends StatelessWidget {
  const _PopularChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);
    return PressScale(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.panelBorder),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: palette.textMuted,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results, required this.onSelect});

  final List<Song> results;
  final ValueChanged<Song> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final song = results[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SongResultTile(
            song: song,
            onTap: () {
              Haptics.stringSelected();
              onSelect(song);
            },
          ),
        );
      },
    );
  }
}

class _SongResultTile extends StatelessWidget {
  const _SongResultTile({required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);
    return Semantics(
      container: true,
      label: '${song.title} by ${song.artist}. Tap to view chord sheet.',
      child: PressScale(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: palette.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.panelBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: palette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 44, color: palette.textMuted),
          const SizedBox(height: 16),
          Text(
            'No songs found',
            style: theme.textTheme.titleMedium?.copyWith(color: palette.text),
          ),
          const SizedBox(height: 6),
          Text(
            'Try another query',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 44, color: palette.textMuted),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: theme.textTheme.titleMedium?.copyWith(color: palette.text),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}
