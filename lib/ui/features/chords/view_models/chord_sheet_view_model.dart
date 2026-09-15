import 'package:flutter/foundation.dart';

import '../../../../data/repositories/chord_sheet_repository.dart';
import '../../../../domain/models/chord_sheet.dart';
import '../../../../domain/models/song.dart';
import '../../../../domain/use_cases/chord_transposer.dart';

enum ChordSheetViewState { idle, loading, ready, error }

class ChordSheetViewModel extends ChangeNotifier {
  ChordSheetViewModel({
    required ChordSheetRepository repository,
    ChordTransposer transposer = const ChordTransposer(),
  })  : _repository = repository,
        _transposer = transposer;

  final ChordSheetRepository _repository;
  final ChordTransposer _transposer;

  ChordSheetViewState _state = ChordSheetViewState.idle;
  ChordSheetViewState get state => _state;

  ChordSheet? _sheet;
  ChordSheet? get sheet => _sheet;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _selectedChord;
  String? get selectedChord => _selectedChord;

  static const int minTransposition = -12;
  static const int maxTransposition = 12;

  int _transposition = 0;
  int get transposition => _transposition;

  static const double defaultAutoscrollSpeedPx = 60;
  static const double minAutoscrollSpeedPx = 30;
  static const double maxAutoscrollSpeedPx = 150;

  bool _isAutoscrolling = false;
  bool get isAutoscrolling => _isAutoscrolling;

  double _autoscrollSpeedPx = defaultAutoscrollSpeedPx;
  double get autoscrollSpeedPx => _autoscrollSpeedPx;

  double _progress = 0;
  double get progress => _progress;

  void startAutoscroll() {
    if (_isAutoscrolling) return;
    _isAutoscrolling = true;
    notifyListeners();
  }

  void stopAutoscroll() {
    if (!_isAutoscrolling) return;
    _isAutoscrolling = false;
    notifyListeners();
  }

  void setAutoscrollSpeed(double pxPerSecond) {
    final clamped = pxPerSecond.clamp(
      minAutoscrollSpeedPx,
      maxAutoscrollSpeedPx,
    );
    if (clamped == _autoscrollSpeedPx) return;
    _autoscrollSpeedPx = clamped;
    notifyListeners();
  }

  void setProgress(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (clamped == _progress) return;
    _progress = clamped;
    notifyListeners();
  }

  Future<void> load(Song song) async {
    _state = ChordSheetViewState.loading;
    _errorMessage = null;
    _selectedChord = null;
    _transposition = 0;
    _isAutoscrolling = false;
    _autoscrollSpeedPx = defaultAutoscrollSpeedPx;
    _progress = 0;
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

  void transposeUp() {
    if (_transposition < maxTransposition) {
      _transposition++;
      notifyListeners();
    }
  }

  void transposeDown() {
    if (_transposition > minTransposition) {
      _transposition--;
      notifyListeners();
    }
  }

  void resetTransposition() {
    _transposition = 0;
    notifyListeners();
  }

  String transposedChord(String name) =>
      _transposer.transpose(name, _transposition);

  String? get transposedKey {
    final key = _sheet?.key;
    if (key == null) return null;
    return transposedChord(key);
  }
}
