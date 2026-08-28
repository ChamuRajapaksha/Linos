import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/tuning_repository.dart';
import '../../../../data/services/audio_input_service.dart';
import '../../../../data/services/pitch_detection_service.dart';
import '../../../../domain/models/note.dart';
import '../../../../domain/models/pitch_detection.dart';
import '../../../../domain/models/tuning_preset.dart';
import '../../../../domain/use_cases/level_calculator.dart';
import '../../../../domain/use_cases/string_matcher.dart';
import '../../../../domain/use_cases/tuning_status_classifier.dart';

enum TunerViewState {
  loading,
  permissionRequired,
  permissionDenied,
  permissionPermanentlyDenied,
  recording,
  error,
}

class TunerViewModel extends ChangeNotifier {
  TunerViewModel({
    required AudioInputService audioInputService,
    required PitchDetectionService pitchDetectionService,
    required StringMatcher stringMatcher,
    double a4Reference = Note.a4Reference,
    TuningRepository tuningRepository = const TuningRepository(),
  })  : _audioInputService = audioInputService,
        _pitchDetectionService = pitchDetectionService,
        _stringMatcher = stringMatcher,
        _a4Reference = a4Reference,
        _tuningRepository = tuningRepository;

  final AudioInputService _audioInputService;
  final PitchDetectionService _pitchDetectionService;
  final TuningRepository _tuningRepository;
  StringMatcher _stringMatcher;

  String _tuningId = TuningPreset.standard.id;
  String get tuningId => _tuningId;

  List<TuningPreset> get tuningPresets => _tuningRepository.listPresets();

  String get tuningName => _stringMatcher.tuning.name;

  double _a4Reference;
  double get a4Reference => _a4Reference;

  int? _selectedString;
  int? get selectedString => _selectedString;

  MicrophonePermissionState? _permission;
  StreamSubscription<List<double>>? _subscription;
  StreamSubscription<PitchDetection>? _pitchSubscription;

  TunerViewState _state = TunerViewState.loading;
  TunerViewState get state => _state;

  double _level = 0;
  double get level => _level;

  PitchDetection? _pitch;
  PitchDetection? get pitch => _pitch;

  StringMatch? _stringMatch;
  StringMatch? get stringMatch => _stringMatch;

  List<Note> get tuningNotes => _stringMatcher.tuning.notes;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    _errorMessage = null;
    if (_permission == MicrophonePermissionState.granted) {
      await startCapture();
      return;
    }
    try {
      final permission = await _audioInputService.checkPermission();
      _permission = permission;
      if (permission == MicrophonePermissionState.granted) {
        await startCapture();
        return;
      }
      _applyDeniedState(permission);
    } catch (error) {
      _handleError(error);
    }
  }

  Future<void> requestPermission() async {
    _errorMessage = null;
    try {
      final permission = await _audioInputService.requestPermission();
      _permission = permission;
      if (permission == MicrophonePermissionState.granted) {
        await startCapture();
        return;
      }
      _applyDeniedState(permission);
    } catch (error) {
      _handleError(error);
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _pitchSubscription?.cancel();
    _pitchSubscription = null;
    _pitch = null;
    _stringMatch = null;
    _level = 0;
    await _audioInputService.stop().catchError((Object _) {});
    await _pitchDetectionService.stop().catchError((Object _) {});
    _setState(TunerViewState.loading);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _pitchSubscription?.cancel();
    _pitchSubscription = null;
    unawaited(_audioInputService.stop());
    unawaited(_pitchDetectionService.dispose());
    super.dispose();
  }

  Future<void> startCapture() async {
    _errorMessage = null;
    try {
      await _audioInputService.start();
      await _subscription?.cancel();
      _subscription = _audioInputService.audioSamples.listen(
        _onSamples,
        onError: _handleError,
        onDone: _onStreamDone,
      );
      await _pitchSubscription?.cancel();
      _pitchSubscription = null;
      await _pitchDetectionService.start();
      _pitchSubscription = _pitchDetectionService.pitchStream.listen(_onPitch);
      _setState(TunerViewState.recording);
    } catch (error) {
      _handleError(error);
    }
  }

  void _applyDeniedState(MicrophonePermissionState permission) {
    switch (permission) {
      case MicrophonePermissionState.denied:
      case MicrophonePermissionState.unknown:
        _setState(TunerViewState.permissionRequired);
      case MicrophonePermissionState.permanentlyDenied:
        _setState(TunerViewState.permissionPermanentlyDenied);
      case MicrophonePermissionState.restricted:
        _errorMessage = 'Microphone access is restricted by the system.';
        _setState(TunerViewState.permissionDenied);
      case MicrophonePermissionState.granted:
        break;
    }
  }

  void _onSamples(List<double> samples) {
    _level = computeRmsLevel(samples);
    notifyListeners();
  }

  void _onPitch(PitchDetection detection) {
    _pitch = detection;
    _stringMatch = _selectedString != null
        ? _stringMatcher.identifyString(
            _selectedString!,
            detection.frequency.value,
          )
        : _stringMatcher.identify(detection.frequency.value);
    notifyListeners();
  }

  void selectString(int? stringIndex) {
    _selectedString = stringIndex;
    if (_pitch != null) {
      _onPitch(_pitch!);
    }
    notifyListeners();
  }

  Future<void> selectTuning(String id) async {
    if (id == _tuningId) {
      return;
    }
    if (!_applyTuning(id)) {
      return;
    }
    notifyListeners();
  }

  bool _applyTuning(String id) {
    final preset = _tuningRepository.getPreset(id);
    if (preset == null) {
      return false;
    }
    _tuningId = id;
    _stringMatcher = StringMatcher(
      tuning: preset.tuningFor(_a4Reference),
      classifier: const TuningStatusClassifier(),
    );
    if (_pitch != null) {
      _onPitch(_pitch!);
    }
    return true;
  }

  void setReferencePitch(double reference) {
    if (reference <= 0 || reference == _a4Reference) {
      return;
    }
    _a4Reference = reference;
    final preset =
        _tuningRepository.getPreset(_tuningId) ?? TuningPreset.standard;
    _stringMatcher = StringMatcher(
      tuning: preset.tuningFor(reference),
      classifier: const TuningStatusClassifier(),
    );
    if (_pitch != null) {
      _onPitch(_pitch!);
    }
    notifyListeners();
  }

  void _onStreamDone() {
    _subscription = null;
    _pitchSubscription?.cancel();
    _pitchSubscription = null;
    _errorMessage = 'Audio stream ended unexpectedly.';
    _setState(TunerViewState.error);
  }

  void _handleError(Object error) {
    _subscription?.cancel();
    _subscription = null;
    _pitchSubscription?.cancel();
    _pitchSubscription = null;
    _pitch = null;
    _stringMatch = null;
    unawaited(_pitchDetectionService.stop());
    _errorMessage = error.toString();
    _setState(TunerViewState.error);
  }

  void _setState(TunerViewState value) {
    _state = value;
    notifyListeners();
  }
}