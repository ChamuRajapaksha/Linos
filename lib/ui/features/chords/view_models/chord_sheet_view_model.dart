import 'package:flutter/foundation.dart';

import '../../../../data/repositories/chord_sheet_repository.dart';
import '../../../../domain/models/chord_sheet.dart';
import '../../../../domain/models/song.dart';

enum ChordSheetViewState { idle, loading, ready, error }

class ChordSheetViewModel extends ChangeNotifier {
  ChordSheetViewModel({required ChordSheetRepository repository})
      : _repository = repository;

  final ChordSheetRepository _repository;

  ChordSheetViewState _state = ChordSheetViewState.idle;
  ChordSheetViewState get state => _state;

  ChordSheet? _sheet;
  ChordSheet? get sheet => _sheet;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _selectedChord;
  String? get selectedChord => _selectedChord;

  Future<void> load(Song song) async {
    _state = ChordSheetViewState.loading;
    _errorMessage = null;
    _selectedChord = null;
    notifyListeners();
    try {
      _sheet = await _repository.fetch(song);
      _state = ChordSheetViewState.ready;
    } catch (e) {
      _sheet = null;
      _state = ChordSheetViewState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  void selectChord(String? chord) {
    _selectedChord = chord;
    notifyListeners();
  }
}
