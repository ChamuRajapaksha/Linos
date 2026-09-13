import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/repositories/song_search_repository.dart';
import 'package:linos/domain/models/search_results.dart';
import 'package:linos/domain/models/song.dart';
import 'package:linos/ui/features/chords/view_models/song_search_view_model.dart';

class FakeSongSearchRepository implements SongSearchRepository {
  List<Song> catalog = [];
  Object? error;
  int pageSize = 100;

  @override
  Future<SearchResults> search(String query, {int page = 1}) async {
    if (error != null) throw error!;
    final filtered = catalog
        .where((s) =>
            s.title.toLowerCase().contains(query.toLowerCase()) ||
            s.artist.toLowerCase().contains(query.toLowerCase()))
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

class StallingSongSearchRepository implements SongSearchRepository {
  final Completer<SearchResults> firstSearch = Completer<SearchResults>();
  bool _started = false;
  List<Song> laterResults = const [];

  @override
  Future<SearchResults> search(String query, {int page = 1}) {
    if (!_started) {
      _started = true;
      return firstSearch.future;
    }
    return Future.value(
      SearchResults(items: laterResults, page: 1, hasMore: false),
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

const wonderwall = Song(id: 'wonderwall', title: 'Wonderwall', artist: 'Oasis');
const ladyInBlack = Song(
  id: 'lady-in-black',
  title: 'Lady In Black',
  artist: 'Uriah Heep',
);

Song numberedSong(int n) =>
    Song(id: 'song-$n', title: 'Song $n', artist: 'Artist');

void main() {
  group('SongSearchViewModel', () {
    test('initial state is idle with empty query and results', () {
      final vm = SongSearchViewModel(
        repository: FakeSongSearchRepository(),
        debounce: Duration.zero,
      );

      expect(vm.state, SongSearchState.idle);
      expect(vm.query, isEmpty);
      expect(vm.results, isEmpty);
      expect(vm.errorMessage, isNull);
      expect(vm.selectedSong, isNull);
    });

    test('onQueryChanged debounces then shows matching results', () async {
      final repo = FakeSongSearchRepository()
        ..catalog = [wonderwall, ladyInBlack];
      final vm = SongSearchViewModel(
        repository: repo,
        debounce: const Duration(milliseconds: 20),
      );

      vm.onQueryChanged('won');
      expect(vm.query, 'won');
      expect(vm.state, SongSearchState.idle);

      await Future.delayed(const Duration(milliseconds: 40));
      await pumpEventQueue();

      expect(vm.state, SongSearchState.results);
      expect(vm.results, [wonderwall]);
    });

    test('rapid onQueryChanged edits debounce to a single search', () async {
      final repo = FakeSongSearchRepository()..catalog = [wonderwall];
      final vm = SongSearchViewModel(
        repository: repo,
        debounce: const Duration(milliseconds: 20),
      );

      vm.onQueryChanged('w');
      vm.onQueryChanged('wo');
      vm.onQueryChanged('won');
      await Future.delayed(const Duration(milliseconds: 40));
      await pumpEventQueue();

      expect(vm.state, SongSearchState.results);
      expect(vm.results, [wonderwall]);
    });

    test('empty query resets to idle', () async {
      final vm = SongSearchViewModel(
        repository: FakeSongSearchRepository()..catalog = [wonderwall],
        debounce: const Duration(milliseconds: 20),
      );

      vm.onQueryChanged('won');
      await Future.delayed(const Duration(milliseconds: 40));
      await pumpEventQueue();
      expect(vm.state, SongSearchState.results);

      vm.onQueryChanged('   ');
      expect(vm.state, SongSearchState.idle);
      expect(vm.query, isEmpty);
      expect(vm.results, isEmpty);
      expect(vm.selectedSong, isNull);
    });

    test('no matches sets empty state with empty results', () async {
      final repo = FakeSongSearchRepository()..catalog = [wonderwall];
      final vm = SongSearchViewModel(
        repository: repo,
        debounce: Duration.zero,
      );

      vm.onQueryChanged('zzz');
      await pumpEventQueue();

      expect(vm.state, SongSearchState.empty);
      expect(vm.results, isEmpty);
    });

    test('repository error sets error state and a later search recovers',
        () async {
      final repo = FakeSongSearchRepository()..catalog = [wonderwall];
      final vm = SongSearchViewModel(repository: repo, debounce: Duration.zero);

      repo.error = StateError('boom');
      await vm.search('won');

      expect(vm.state, SongSearchState.error);
      expect(vm.errorMessage, contains('boom'));

      repo.error = null;
      await vm.search('won');

      expect(vm.state, SongSearchState.results);
      expect(vm.errorMessage, isNull);
      expect(vm.results, [wonderwall]);
    });

    test('direct search trims input and ignores empty queries', () async {
      final repo = FakeSongSearchRepository()..catalog = [wonderwall];
      final vm = SongSearchViewModel(repository: repo, debounce: Duration.zero);

      await vm.search(' won ');
      expect(vm.state, SongSearchState.results);
      expect(vm.results, [wonderwall]);

      await vm.search('   ');
      expect(vm.state, SongSearchState.idle);
      expect(vm.results, isEmpty);
    });

    test('selectSong sets the selected song', () {
      final vm = SongSearchViewModel(
        repository: FakeSongSearchRepository(),
        debounce: Duration.zero,
      );

      vm.selectSong(wonderwall);

      expect(vm.selectedSong, wonderwall);
    });

    test('clear resets query, results, selection and state to idle', () async {
      final repo = FakeSongSearchRepository()..catalog = [wonderwall];
      final vm = SongSearchViewModel(
        repository: repo,
        debounce: const Duration(milliseconds: 20),
      );

      vm.onQueryChanged('won');
      await Future.delayed(const Duration(milliseconds: 40));
      await pumpEventQueue();
      vm.selectSong(wonderwall);
      expect(vm.state, SongSearchState.results);

      vm.clear();

      expect(vm.state, SongSearchState.idle);
      expect(vm.query, isEmpty);
      expect(vm.results, isEmpty);
      expect(vm.selectedSong, isNull);
      expect(vm.errorMessage, isNull);
    });

    test('stale search results are dropped when a newer search starts',
        () async {
      const alpha = Song(id: 'alpha', title: 'Alpha', artist: 'Kim');
      const bold = Song(id: 'bold', title: 'Bold', artist: 'Kim');
      final repo = StallingSongSearchRepository()..laterResults = [bold];
      final vm = SongSearchViewModel(repository: repo, debounce: Duration.zero);

      final first = vm.search('a');
      final second = vm.search('b');
      await second;
      expect(vm.results, [bold]);

      repo.firstSearch.complete(
        const SearchResults(items: [alpha], page: 1, hasMore: false),
      );
      await first;

      expect(vm.state, SongSearchState.results);
      expect(vm.results, [bold]);
    });

    group('pagination', () {
      test('loadMore appends results, bumps page and updates hasMore',
          () async {
        final repo = FakeSongSearchRepository()
          ..catalog = [numberedSong(1), numberedSong(2), numberedSong(3)]
          ..pageSize = 1;
        final vm = SongSearchViewModel(
          repository: repo,
          debounce: Duration.zero,
        );

        await vm.search('song');
        expect(vm.results.length, 1);
        expect(vm.page, 1);
        expect(vm.hasMore, true);

        await vm.loadMore();
        expect(vm.results.length, 2);
        expect(vm.page, 2);
        expect(vm.hasMore, true);

        await vm.loadMore();
        expect(vm.results.length, 3);
        expect(vm.page, 3);
        expect(vm.hasMore, false);
      });

      test('loadMore is a no-op when hasMore is false', () async {
        final repo = FakeSongSearchRepository()
          ..catalog = [numberedSong(1), numberedSong(2)]
          ..pageSize = 10;
        final vm = SongSearchViewModel(
          repository: repo,
          debounce: Duration.zero,
        );

        await vm.search('song');
        expect(vm.results.length, 2);
        expect(vm.hasMore, false);
        expect(vm.page, 1);

        await vm.loadMore();

        expect(vm.results.length, 2);
        expect(vm.page, 1);
        expect(vm.hasMore, false);
        expect(vm.isLoadingMore, false);
      });

      test('loadMore is ignored while already loading', () async {
        final repo = GatedSongSearchRepository(
          catalog: [numberedSong(1), numberedSong(2)],
          pageSize: 1,
        );
        final vm = SongSearchViewModel(
          repository: repo,
          debounce: Duration.zero,
        );

        await vm.search('song');
        expect(vm.hasMore, true);

        final firstLoad = vm.loadMore();
        await vm.loadMore();

        expect(repo.pageCalls[2], 1);
        expect(vm.isLoadingMore, true);

        repo.completePage(2);
        await firstLoad;

        expect(vm.results.length, 2);
        expect(vm.isLoadingMore, false);
      });

      test('loadMore failure keeps results and does not flip to error',
          () async {
        final repo = FakeSongSearchRepository()
          ..catalog = [numberedSong(1), numberedSong(2), numberedSong(3)]
          ..pageSize = 1;
        final vm = SongSearchViewModel(
          repository: repo,
          debounce: Duration.zero,
        );

        await vm.search('song');
        repo.error = StateError('boom');
        await vm.loadMore();

        expect(vm.state, SongSearchState.results);
        expect(vm.results.length, 1);
        expect(vm.isLoadingMore, false);
        expect(vm.errorMessage, isNull);

        repo.error = null;
        await vm.loadMore();

        expect(vm.results.length, 2);
      });

      test('stale loadMore from an old query is dropped', () async {
        final repo = GatedSongSearchRepository(
          catalog: [numberedSong(1), numberedSong(2), numberedSong(3)],
          pageSize: 1,
        );
        final vm = SongSearchViewModel(
          repository: repo,
          debounce: Duration.zero,
        );

        await vm.search('song');
        expect(vm.results, [numberedSong(1)]);
        expect(vm.hasMore, true);

        final staleLoad = vm.loadMore();

        await vm.search('3');
        expect(vm.results, [numberedSong(3)]);

        repo.completePage(2);
        await staleLoad;

        expect(vm.results, [numberedSong(3)]);
        expect(vm.state, SongSearchState.results);
        expect(vm.isLoadingMore, false);
      });

      test('new search resets page, hasMore and isLoadingMore', () async {
        final repo = FakeSongSearchRepository()
          ..catalog = [numberedSong(1), numberedSong(2), numberedSong(3)]
          ..pageSize = 1;
        final vm = SongSearchViewModel(
          repository: repo,
          debounce: Duration.zero,
        );

        await vm.search('song');
        await vm.loadMore();
        expect(vm.results.length, 2);
        expect(vm.page, 2);
        expect(vm.hasMore, true);

        await vm.search('song');

        expect(vm.results.length, 1);
        expect(vm.page, 1);
        expect(vm.hasMore, true);
        expect(vm.isLoadingMore, false);
      });
    });
  });
}