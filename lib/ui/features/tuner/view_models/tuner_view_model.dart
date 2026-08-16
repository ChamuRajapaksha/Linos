import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/services/audio_input_service.dart';
import '../../../../domain/use_cases/level_calculator.dart';

enum TunerViewState {
  loading,
  permissionRequired,
  permissionDenied,
  permissionPermanentlyDenied,
  recording,
  error,
}

class TunerViewModel extends ChangeNotifier {
  TunerViewModel({required AudioInputService audioInputService})
      : _audioInputService = audioInputService;

  final AudioInputService _audioInputService;

  MicrophonePermissionState? _permission;
  StreamSubscription<List<double>>? _subscription;

  TunerViewState _state = TunerViewState.loading;
  TunerViewState get state => _state;

  double _level = 0;
  double get level => _level;

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
    _level = 0;
    await _audioInputService.stop().catchError((Object _) {});
    _setState(TunerViewState.loading);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    unawaited(_audioInputService.stop());
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

  void _onStreamDone() {
    _subscription = null;
    _errorMessage = 'Audio stream ended unexpectedly.';
    _setState(TunerViewState.error);
  }

  void _handleError(Object error) {
    _subscription?.cancel();
    _subscription = null;
    _errorMessage = error.toString();
    _setState(TunerViewState.error);
  }

  void _setState(TunerViewState value) {
    _state = value;
    notifyListeners();
  }
}