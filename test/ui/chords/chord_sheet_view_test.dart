import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/repositories/chord_sheet_repository.dart';
import 'package:linos/domain/models/chord_sheet.dart';
import 'package:linos/domain/models/song.dart';
import 'package:linos/ui/core/theme/app_theme.dart';
import 'package:linos/ui/features/chords/view_models/chord_sheet_view_model.dart';
import 'package:linos/ui/features/chords/views/chord_sheet_view.dart';

class FakeChordSheetRepository implements ChordSheetRepository {
  ChordSheet? sheet;
  Object? error;

  @override
  Future<ChordSheet> fetch(Song song) async {
    if (error != null) throw error!;
    if (sheet == null) throw StateError('No sheet for ${song.id}');
    return sheet!;
  }
}

class StallingChordSheetRepository implements ChordSheetRepository {
  final Completer<ChordSheet> completer = Completer<ChordSheet>();

  @override
  Future<ChordSheet> fetch(Song song) => completer.future;
}

const _testSong = Song(id: 's1', title: 'Test Song', artist: 'Test Artist');

const _testSheet = ChordSheet(
  title: 'Test Song',
  artist: 'Test Artist',
  key: 'G',
  lines: [
    SongSection('Verse'),
    LyricLine([
      WordChord(word: 'Hello', chord: 'C'),
      WordChord(word: 'world', chord: 'G'),
    ]),
  ],
);

Future<void> pumpSheet(
  WidgetTester tester, {
  ChordSheet? sheet,
}) async {
  final repo = FakeChordSheetRepository()..sheet = sheet;
  final vm = ChordSheetViewModel(repository: repo);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: ChordSheetView(song: _testSong, viewModel: vm),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('after load, title and artist are visible', (tester) async {
    await pumpSheet(tester, sheet: _testSheet);

    expect(find.text('Test Song'), findsOneWidget);
    expect(find.text('Test Artist'), findsOneWidget);
  });

  testWidgets('section label is visible', (tester) async {
    await pumpSheet(tester, sheet: _testSheet);

    expect(find.text('VERSE'), findsOneWidget);
  });

  testWidgets('chord labels are visible', (tester) async {
    await pumpSheet(tester, sheet: _testSheet);

    expect(find.text('C'), findsOneWidget);
    // 'G' also appears as the key chip.
    expect(find.text('G'), findsWidgets);
  });

  testWidgets('lyric words are visible', (tester) async {
    await pumpSheet(tester, sheet: _testSheet);

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('world'), findsOneWidget);
  });

  testWidgets('back button is present', (tester) async {
    await pumpSheet(tester, sheet: _testSheet);

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('key chip is shown when key is present', (tester) async {
    await pumpSheet(tester, sheet: _testSheet);

    // 'G' appears as both the key chip and a chord label.
    expect(find.text('G'), findsNWidgets(2));
  });

  testWidgets('loading state shows spinner', (tester) async {
    final repo = StallingChordSheetRepository();
    final vm = ChordSheetViewModel(repository: repo);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChordSheetView(song: _testSong, viewModel: vm),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repo.completer.complete(_testSheet);
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('error view shows retry button', (tester) async {
    final repo = FakeChordSheetRepository()..error = Exception('fail');
    final vm = ChordSheetViewModel(repository: repo);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChordSheetView(song: _testSong, viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load chord sheet."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping a chord calls selectChord', (tester) async {
    final repo = FakeChordSheetRepository()..sheet = _testSheet;
    final vm = ChordSheetViewModel(repository: repo);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChordSheetView(song: _testSong, viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hello'));
    await tester.pump();

    expect(vm.selectedChord, 'C');
  });
}