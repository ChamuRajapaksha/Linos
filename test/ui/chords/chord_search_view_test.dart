import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/repositories/chord_sheet_repository.dart';
import 'package:linos/data/repositories/song_search_repository.dart';
import 'package:linos/di/locator.dart';
import 'package:linos/domain/models/chord_sheet.dart';
import 'package:linos/domain/models/song.dart';
import 'package:linos/ui/core/theme/app_theme.dart';
import 'package:linos/ui/features/chords/view_models/song_search_view_model.dart';
import 'package:linos/ui/features/chords/views/chord_search_view.dart';
import 'package:linos/ui/features/chords/views/chord_sheet_view.dart';

class FakeSongSearchRepository implements SongSearchRepository {
  List<Song> catalog = [];
  Object? error;

  @override
  Future<List<Song>> search(String query) async {
    if (error != null) throw error!;
    final q = query.trim().toLowerCase();
    return catalog
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q))
        .toList();
  }
}

class FakeChordSheetRepository implements ChordSheetRepository {
  ChordSheet? sheet;

  @override
  Future<ChordSheet> fetch(Song song) async {
    if (sheet == null) throw StateError('No sheet for ${song.id}');
    return sheet!;
  }
}

const _testSong = Song(id: 's1', title: 'Test Song', artist: 'Test Artist');

const _testSheet = ChordSheet(
  title: 'Test Song',
  artist: 'Test Artist',
  lines: [SongSection('Verse'), LyricLine([])],
);

Future<SongSearchViewModel> pumpSearch(
  WidgetTester tester, {
  List<Song> catalog = const [],
}) async {
  final repo = FakeSongSearchRepository()..catalog = catalog;
  final vm = SongSearchViewModel(
    repository: repo,
    debounce: const Duration(milliseconds: 20),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: ChordSearchView(viewModel: vm),
    ),
  );
  await tester.pump();
  return vm;
}

void main() {
  setUpAll(() async {
    await locator.reset();
    locator.registerSingleton<ChordSheetRepository>(
      FakeChordSheetRepository()..sheet = _testSheet,
    );
    Locator.init();
  });

  testWidgets('idle state shows hint text and popular chips', (tester) async {
    await pumpSearch(tester);

    expect(find.text('Search by title or artist'), findsOneWidget);
    expect(find.text('Wonderwall'), findsOneWidget);
    expect(find.text('Radioactive'), findsOneWidget);
    expect(find.text('Creep'), findsOneWidget);
    expect(find.text('Imagine'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
  });

  testWidgets('typing into search field shows results', (tester) async {
    await pumpSearch(tester, catalog: [_testSong]);

    await tester.enterText(find.byType(TextField), 'test');
    // Debounce fires after 20ms.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Test Song'), findsOneWidget);
    expect(find.text('Test Artist'), findsOneWidget);
  });

  testWidgets('empty result shows empty state', (tester) async {
    await pumpSearch(tester, catalog: []);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('No songs found'), findsOneWidget);
  });

  testWidgets('error state shows error message and try again', (tester) async {
    final repo = FakeSongSearchRepository()..catalog = [_testSong];
    final vm = SongSearchViewModel(
      repository: repo,
      debounce: const Duration(milliseconds: 20),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChordSearchView(viewModel: vm),
      ),
    );
    await tester.pump();

    repo.error = Exception('network fail');
    await tester.enterText(find.byType(TextField), 'test');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('no back button on main search screen', (tester) async {
    await pumpSearch(tester);

    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('popular chip tap fills search bar', (tester) async {
    final vm = await pumpSearch(tester, catalog: [_testSong]);

    await tester.tap(find.text('Wonderwall'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(vm.query, 'Wonderwall');
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('search bar shows clear button when text is entered',
      (tester) async {
    await pumpSearch(tester);

    expect(find.byIcon(Icons.clear), findsNothing);

    await tester.enterText(find.byType(TextField), 'test');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.clear), findsOneWidget);
  });

  testWidgets('clear button resets search', (tester) async {
    final vm = await pumpSearch(tester, catalog: [_testSong]);

    await tester.enterText(find.byType(TextField), 'test');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(vm.state, SongSearchState.results);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(vm.state, SongSearchState.idle);
    expect(vm.query, isEmpty);
  });

  testWidgets('tapping a result tile pushes the chord sheet view',
      (tester) async {
    await pumpSearch(tester, catalog: [_testSong]);

    await tester.enterText(find.byType(TextField), 'test');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Test Song'), findsOneWidget);
    await tester.tap(find.text('Test Song'));
    await tester.pumpAndSettle();

    expect(find.byType(ChordSheetView), findsOneWidget);
  });
}