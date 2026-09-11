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
}
