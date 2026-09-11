import 'package:flutter/material.dart';

import '../theme/linos_palette.dart';
import '../widgets/wordmark.dart';
import '../../features/tuner/views/tuner_view.dart';
import '../../features/tuner/view_models/tuner_view_model.dart';
import '../../features/chords/view_models/song_search_view_model.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.tunerViewModel,
    required this.searchViewModel,
  });

  final TunerViewModel tunerViewModel;
  final SongSearchViewModel searchViewModel;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_index) {
        0 => TunerView(viewModel: widget.tunerViewModel),
        1 => const _ChordsTabPlaceholder(),
        _ => throw StateError('Invalid tab index'),
      },
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: LinosPalette.forBrightness(Theme.of(context).brightness).panelBorder),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.tune), label: 'Tuner'),
              NavigationDestination(icon: Icon(Icons.music_note), label: 'Chords'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChordsTabPlaceholder extends StatelessWidget {
  const _ChordsTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Wordmark(label: 'CHORDS')),
          const Spacer(),
          Center(
            child: Text(
              'Chord search coming soon.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
