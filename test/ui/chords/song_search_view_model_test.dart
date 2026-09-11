import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/repositories/song_search_repository.dart';
import 'package:linos/domain/models/song.dart';
import 'package:linos/ui/features/chords/view_models/song_search_view_model.dart';

class FakeSongSearchRepository implements SongSearchRepository {
  List<Song> catalog = [];
  Object? error;

  @override
  Future<List<Song>> search(String query) async {
    if (error != null) throw error!;
    return catalog
        .where((s) =>
            s.title.toLowerCase().contains(query.toLowerCase()) ||
            s.artist.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}

class StallingSongSearchRepository implements SongSearchRepository {
  final Completer<List<Song>> firstSearch = Completer<List<Song>>();
  bool _started = false;
  List<Song> laterResults = const [];

  @override
  Future<List<Song>> search(String query) {
    if (!_started) {
      _started = true;
      return firstSearch.future;
    }
    return Future.value(laterResults);
  }
}

const wonderwall = Song(id: 'wonderwall', title: 'Wonderwall', artist: 'Oasis');
const ladyInBlack = Song(
  id: 'lady-in-black',
  title: 'Lady In Black',
  artist: 'Uriah Heep',
);

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

      repo.firstSearch.complete([alpha]);
      await first;

      expect(vm.state, SongSearchState.results);
      expect(vm.results, [bold]);
    });
  });
}