import 'package:flutter/material.dart';

import '../theme/linos_palette.dart';
import '../../features/tuner/views/tuner_view.dart';
import '../../features/tuner/view_models/tuner_view_model.dart';
import '../../features/chords/view_models/song_search_view_model.dart';
import '../../features/chords/views/chord_search_view.dart';

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
        1 => ChordSearchView(viewModel: widget.searchViewModel),
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
