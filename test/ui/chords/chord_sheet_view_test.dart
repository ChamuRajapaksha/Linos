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

  testWidgets('transpose stepper buttons are visible after load', (
    tester,
  ) async {
    await pumpSheet(tester, sheet: _testSheet);

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
  });

  testWidgets('transposing up +1 shows transposed chords and offset label', (
    tester,
  ) async {
    await pumpSheet(tester, sheet: _testSheet);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('C#'), findsOneWidget);
    expect(find.text('G#'), findsNWidgets(2));
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('offset label shows +2 and tapping it resets transposition', (
    tester,
  ) async {
    await pumpSheet(tester, sheet: _testSheet);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('+2'), findsOneWidget);

    await tester.tap(find.text('+2'));
    await tester.pump();

    expect(find.text('0'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('G'), findsNWidgets(2));
  });

  testWidgets('plus button is disabled at +12', (tester) async {
    final repo = FakeChordSheetRepository()..sheet = _testSheet;
    final vm = ChordSheetViewModel(repository: repo);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChordSheetView(song: _testSong, viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 12; i++) {
      vm.transposeUp();
    }
    await tester.pump();

    final addButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.add),
    );
    expect(addButton.onPressed, isNull);
    expect(find.text('+12'), findsOneWidget);
  });

  testWidgets('minus button is disabled at -12', (tester) async {
    final repo = FakeChordSheetRepository()..sheet = _testSheet;
    final vm = ChordSheetViewModel(repository: repo);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChordSheetView(song: _testSong, viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 12; i++) {
      vm.transposeDown();
    }
    await tester.pump();

    final removeButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.remove),
    );
    expect(removeButton.onPressed, isNull);
    expect(find.text('-12'), findsOneWidget);
  });

  testWidgets('tapping chord at +1 opens diagram with transposed name', (
    tester,
  ) async {
    await pumpSheet(tester, sheet: _testSheet);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    await tester.tap(find.text('Hello'));
    await tester.pumpAndSettle();

    expect(find.text('C#'), findsWidgets);
  });

  testWidgets('reset transposition button has correct semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpSheet(tester, sheet: _testSheet);

    final node = tester.getSemantics(find.text('0'));
    expect(node.label, contains('Reset transposition'));

    handle.dispose();
  });
}