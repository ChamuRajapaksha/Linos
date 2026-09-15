import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/repositories/chord_sheet_repository.dart';
import 'package:linos/domain/models/chord_sheet.dart';
import 'package:linos/domain/models/song.dart';
import 'package:linos/ui/features/chords/view_models/chord_sheet_view_model.dart';

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

void main() {
  final song = const Song(id: 's1', title: 'Yesterday', artist: 'Beatles');
  final sheet = const ChordSheet(
    title: 'Yesterday',
    artist: 'Beatles',
    key: 'G',
    lines: [SongSection('Verse'), LyricLine([])],
  );

  group('ChordSheetViewModel', () {
    test('initial state is idle with no sheet', () {
      final vm = ChordSheetViewModel(repository: FakeChordSheetRepository());

      expect(vm.state, ChordSheetViewState.idle);
      expect(vm.sheet, isNull);
      expect(vm.errorMessage, isNull);
      expect(vm.selectedChord, isNull);
    });

    test('load sets state ready and sheet on success', () async {
      final repo = FakeChordSheetRepository()..sheet = sheet;
      final vm = ChordSheetViewModel(repository: repo);

      await vm.load(song);

      expect(vm.state, ChordSheetViewState.ready);
      expect(vm.sheet, sheet);
      expect(vm.sheet!.title, 'Yesterday');
      expect(vm.sheet!.artist, 'Beatles');
    });

    test('load sets error state when repository throws', () async {
      final repo = FakeChordSheetRepository()
        ..error = Exception('network down');
      final vm = ChordSheetViewModel(repository: repo);

      await vm.load(song);

      expect(vm.state, ChordSheetViewState.error);
      expect(vm.sheet, isNull);
      expect(vm.errorMessage, contains('network down'));
    });

    test('successful load after error recovers to ready', () async {
      final repo = FakeChordSheetRepository()..error = Exception('fail');
      final vm = ChordSheetViewModel(repository: repo);

      await vm.load(song);
      expect(vm.state, ChordSheetViewState.error);

      repo.error = null;
      repo.sheet = sheet;
      await vm.load(song);

      expect(vm.state, ChordSheetViewState.ready);
      expect(vm.sheet, sheet);
      expect(vm.errorMessage, isNull);
    });

    test('selectChord sets and clears selectedChord', () {
      final vm = ChordSheetViewModel(repository: FakeChordSheetRepository());

      vm.selectChord('C');
      expect(vm.selectedChord, 'C');

      vm.selectChord(null);
      expect(vm.selectedChord, isNull);
    });
  });

  group('transposition', () {
    final chordSheet = const ChordSheet(
      title: 'Yesterday',
      artist: 'Beatles',
      key: 'G',
      lines: [
        SongSection('Verse'),
        LyricLine([
          WordChord(word: 'I', chord: 'C'),
          WordChord(word: 'need', chord: 'G'),
          WordChord(word: 'you', chord: 'Am'),
        ]),
      ],
    );

    test('initial transposition is 0 and chords are unchanged', () async {
      final repo = FakeChordSheetRepository()..sheet = chordSheet;
      final vm = ChordSheetViewModel(repository: repo);
      await vm.load(song);

      expect(vm.transposition, 0);
      expect(vm.transposedChord('C'), 'C');
      expect(vm.transposedKey, 'G');
    });

    test('transposeUp moves +1 each call', () async {
      final repo = FakeChordSheetRepository()..sheet = chordSheet;
      final vm = ChordSheetViewModel(repository: repo);
      await vm.load(song);

      vm.transposeUp();
      expect(vm.transposition, 1);
      expect(vm.transposedChord('C'), 'C#');

      vm.transposeUp();
      expect(vm.transposition, 2);
      expect(vm.transposedChord('C'), 'D');
    });

    test('transposeDown moves -1', () async {
      final repo = FakeChordSheetRepository()..sheet = chordSheet;
      final vm = ChordSheetViewModel(repository: repo);
      await vm.load(song);

      vm.transposeDown();
      expect(vm.transposition, -1);
      expect(vm.transposedChord('C'), 'B');
      expect(vm.transposedChord('B'), 'A#');
    });

    test('transposeDown clamps at minTransposition', () async {
      final repo = FakeChordSheetRepository()..sheet = chordSheet;
      final vm = ChordSheetViewModel(repository: repo);
      await vm.load(song);

      for (var i = 0; i < 13; i++) {
        vm.transposeDown();
      }
      expect(vm.transposition, ChordSheetViewModel.minTransposition);
      expect(vm.transposition, -12);
    });

    test('transposeUp clamps at maxTransposition', () async {
      final repo = FakeChordSheetRepository()..sheet = chordSheet;
      final vm = ChordSheetViewModel(repository: repo);
      await vm.load(song);

      for (var i = 0; i < 13; i++) {
        vm.transposeUp();
      }
      expect(vm.transposition, ChordSheetViewModel.maxTransposition);
      expect(vm.transposition, 12);
    });

    test('resetTransposition returns to 0', () async {
      final repo = FakeChordSheetRepository()..sheet = chordSheet;
      final vm = ChordSheetViewModel(repository: repo);
      await vm.load(song);

      for (var i = 0; i < 5; i++) {
        vm.transposeUp();
      }
      expect(vm.transposition, 5);
      expect(vm.transposedChord('C'), 'F');

      vm.resetTransposition();
      expect(vm.transposition, 0);
      expect(vm.transposedChord('C'), 'C');
    });

    test('transposedKey reflects transposition with key G +2 → A', () async {
      final repo = FakeChordSheetRepository()..sheet = chordSheet;
      final vm = ChordSheetViewModel(repository: repo);
      await vm.load(song);

      vm.transposeUp();
      vm.transposeUp();
      expect(vm.transposedKey, 'A');
    });

    test('transposedKey is null when sheet has no key', () async {
      final noKeySheet = const ChordSheet(
        title: 'Untitled',
        artist: 'Unknown',
        lines: [],
      );
      final repo = FakeChordSheetRepository()..sheet = noKeySheet;
      final vm = ChordSheetViewModel(repository: repo);
      await vm.load(song);

      expect(vm.transposedKey, isNull);
    });

    test('load() resets transposition to 0', () async {
      final repo = FakeChordSheetRepository()..sheet = chordSheet;
      final vm = ChordSheetViewModel(repository: repo);
      await vm.load(song);

      for (var i = 0; i < 3; i++) {
        vm.transposeUp();
      }
      expect(vm.transposition, 3);

      await vm.load(song);
      expect(vm.transposition, 0);
    });
  });

  group('autoscroll', () {
    test('initial values are stopped at default speed and progress 0', () {
      final vm = ChordSheetViewModel(repository: FakeChordSheetRepository());

      expect(vm.isAutoscrolling, isFalse);
      expect(vm.autoscrollSpeedPx, 60);
      expect(vm.progress, 0);
    });

    test('start sets true and repeated start is a no-op', () {
      final vm = ChordSheetViewModel(repository: FakeChordSheetRepository());
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.startAutoscroll();
      expect(vm.isAutoscrolling, isTrue);
      expect(notifications, 1);

      vm.startAutoscroll();
      expect(vm.isAutoscrolling, isTrue);
      expect(notifications, 1);
    });

    test('stop sets false and repeated stop is a no-op', () {
      final vm = ChordSheetViewModel(repository: FakeChordSheetRepository());
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.stopAutoscroll();
      expect(vm.isAutoscrolling, isFalse);
      expect(notifications, 0);

      vm.startAutoscroll();
      vm.stopAutoscroll();
      expect(vm.isAutoscrolling, isFalse);
      expect(notifications, 2);

      vm.stopAutoscroll();
      expect(notifications, 2);
    });

    test('setAutoscrollSpeed applies a value within range', () {
      final vm = ChordSheetViewModel(repository: FakeChordSheetRepository());

      vm.setAutoscrollSpeed(90);
      expect(vm.autoscrollSpeedPx, 90);

      vm.setAutoscrollSpeed(120.5);
      expect(vm.autoscrollSpeedPx, 120.5);
    });

    test('setAutoscrollSpeed clamps at min and max', () {
      final vm = ChordSheetViewModel(repository: FakeChordSheetRepository());

      vm.setAutoscrollSpeed(10);
      expect(vm.autoscrollSpeedPx, 30);

      vm.setAutoscrollSpeed(500);
      expect(vm.autoscrollSpeedPx, 150);
    });

    test('setAutoscrollSpeed does not notify when unchanged', () {
      final vm = ChordSheetViewModel(repository: FakeChordSheetRepository());
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.setAutoscrollSpeed(60);
      expect(notifications, 0);

      vm.setAutoscrollSpeed(20);
      expect(vm.autoscrollSpeedPx, 30);
      expect(notifications, 1);

      vm.setAutoscrollSpeed(25);
      expect(notifications, 1);
    });

    test('setProgress clamps to 0..1', () {
      final vm = ChordSheetViewModel(repository: FakeChordSheetRepository());

      vm.setProgress(0.5);
      expect(vm.progress, 0.5);

      vm.setProgress(-1);
      expect(vm.progress, 0);

      vm.setProgress(2);
      expect(vm.progress, 1);
    });

    test('setProgress does not notify when unchanged', () {
      final vm = ChordSheetViewModel(repository: FakeChordSheetRepository());
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.setProgress(0.5);
      expect(notifications, 1);

      vm.setProgress(0.5);
      expect(notifications, 1);
    });

    test('load() resets autoscroll state', () async {
      final repo = FakeChordSheetRepository()..sheet = sheet;
      final vm = ChordSheetViewModel(repository: repo);
      await vm.load(song);

      vm.startAutoscroll();
      vm.setAutoscrollSpeed(90);
      vm.setProgress(0.5);
      expect(vm.isAutoscrolling, isTrue);
      expect(vm.autoscrollSpeedPx, 90);
      expect(vm.progress, 0.5);

      await vm.load(song);

      expect(vm.isAutoscrolling, isFalse);
      expect(vm.autoscrollSpeedPx, 60);
      expect(vm.progress, 0);
    });
  });
}
