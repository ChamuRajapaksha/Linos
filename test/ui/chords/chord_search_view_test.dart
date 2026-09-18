import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linos/data/repositories/chord_sheet_repository.dart';
import 'package:linos/data/repositories/song_search_repository.dart';
import 'package:linos/di/locator.dart';
import 'package:linos/domain/models/chord_sheet.dart';
import 'package:linos/domain/models/search_results.dart';
import 'package:linos/domain/models/song.dart';
import 'package:linos/ui/core/theme/app_theme.dart';
import 'package:linos/ui/features/chords/view_models/song_search_view_model.dart';
import 'package:linos/ui/features/chords/views/chord_search_view.dart';
import 'package:linos/ui/features/chords/views/chord_sheet_view.dart';

class FakeSongSearchRepository implements SongSearchRepository {
  List<Song> catalog = [];
  Object? error;
  int pageSize = 100;
  int searchCalls = 0;

  @override
  Future<SearchResults> search(String query, {int page = 1}) async {
    searchCalls++;
    if (error != null) throw error!;
    final q = query.trim().toLowerCase();
    final filtered = catalog
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q))
        .toList();
    final start = (page - 1) * pageSize;
    final slice = start >= filtered.length
        ? const <Song>[]
        : filtered.skip(start).take(pageSize).toList();
    return SearchResults(
      items: slice,
      page: page,
      hasMore: (page * pageSize) < filtered.length,
    );
  }
}

/// Paginated fake whose page 1 resolves immediately but every page >= 2 is
/// gated on a per-page [Completer] the test completes via [completePage].
class GatedSongSearchRepository implements SongSearchRepository {
  GatedSongSearchRepository({required this.catalog, this.pageSize = 10});

  final List<Song> catalog;
  final int pageSize;
  int searchCalls = 0;
  final Map<int, int> pageCalls = {};
  final Map<int, Completer<void>> gates = {};

  void completePage(int page) {
    gates[page]?.complete();
  }

  SearchResults _resultsFor(int page, String query) {
    final q = query.trim().toLowerCase();
    final filtered = catalog
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q))
        .toList();
    final start = (page - 1) * pageSize;
    final slice = start >= filtered.length
        ? const <Song>[]
        : filtered.skip(start).take(pageSize).toList();
    return SearchResults(
      items: slice,
      page: page,
      hasMore: (page * pageSize) < filtered.length,
    );
  }

  @override
  Future<SearchResults> search(String query, {int page = 1}) {
    searchCalls++;
    pageCalls[page] = (pageCalls[page] ?? 0) + 1;
    if (page <= 1) {
      return Future.value(_resultsFor(page, query));
    }
    final gate = gates.putIfAbsent(page, Completer<void>.new);
    return gate.future.then((_) => _resultsFor(page, query));
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

Future<SongSearchViewModel> pumpSearchWithRepository(
  WidgetTester tester,
  SongSearchRepository repo,
) async {
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

Future<SongSearchViewModel> pumpSearch(
  WidgetTester tester, {
  List<Song> catalog = const [],
  int pageSize = 100,
}) {
  final repo = FakeSongSearchRepository()
    ..catalog = catalog
    ..pageSize = pageSize;
  return pumpSearchWithRepository(tester, repo);
}

void main() {
    SharedPreferences.setMockInitialValues({});
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

  testWidgets(
    'footer loader appears while a next page loads, then results append',
    (tester) async {
      final catalog = List.generate(
        12,
        (i) => Song(id: 'song-$i', title: 'Result ${i + 1}', artist: 'Artist $i'),
      );
      final repo = GatedSongSearchRepository(catalog: catalog, pageSize: 10);
      await pumpSearchWithRepository(tester, repo);

      await tester.enterText(find.byType(TextField), 'result');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Result 1'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      final semantics = tester.ensureSemantics();
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump();

      expect(find.bySemanticsLabel('Loading more results'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      semantics.dispose();

      repo.completePage(2);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Loading more results'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
      expect(find.text('Result 11'), findsOneWidget);
      expect(find.text('Result 12'), findsOneWidget);
    },
  );

  testWidgets('hasMore=false stops further requests', (tester) async {
    final repo = FakeSongSearchRepository()
      ..catalog = [
        Song(id: 'one', title: 'Only One', artist: 'Artist'),
        Song(id: 'two', title: 'Only Two', artist: 'Artist'),
      ]
      ..pageSize = 10;
    await pumpSearchWithRepository(tester, repo);

    await tester.enterText(find.byType(TextField), 'only');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(repo.searchCalls, 1);
    expect(find.text('Only One'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pump();

    expect(repo.searchCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('tapping the star toggles favorite state on a result tile',
      (tester) async {
    await pumpSearch(tester, catalog: [_testSong]);
    await tester.enterText(find.byType(TextField), 'test');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star_outline), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNothing);

    await tester.tap(find.byIcon(Icons.star_outline));
    await tester.pump();

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.star_outline), findsNothing);

    await tester.tap(find.byIcon(Icons.star));
    await tester.pump();

    expect(find.byIcon(Icons.star_outline), findsOneWidget);
  });

  testWidgets('RECENT section appears after a search and Clear empties it',
      (tester) async {
    await pumpSearch(tester, catalog: [_testSong]);

    await tester.enterText(find.byType(TextField), 'test');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('RECENT'), findsOneWidget);
    expect(find.text('test'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('RECENT'), findsNothing);
    expect(find.text('test'), findsNothing);
  });
}
