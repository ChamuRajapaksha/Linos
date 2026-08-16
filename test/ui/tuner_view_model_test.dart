import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/services/audio_input_service.dart';
import 'package:linos/data/services/record_audio_input_service.dart';
import 'package:linos/ui/features/tuner/view_models/tuner_view_model.dart';

class FakeAudioInputService implements AudioInputService {
  FakeAudioInputService({
    this.permissionState = MicrophonePermissionState.denied,
  });

  MicrophonePermissionState permissionState;
  bool throwOnStart = false;
  int startCalls = 0;
  int stopCalls = 0;
  int checkPermissionCalls = 0;

  final StreamController<List<double>> _controller =
      StreamController<List<double>>.broadcast();

  @override
  Stream<List<double>> get audioSamples => _controller.stream;

  @override
  Future<MicrophonePermissionState> checkPermission() async {
    checkPermissionCalls++;
    return permissionState;
  }

  @override
  Future<MicrophonePermissionState> requestPermission() async {
    return permissionState;
  }

  @override
  Future<void> start() async {
    startCalls++;
    if (throwOnStart) {
      throw AudioInputException('start failed');
    }
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  void pushSamples(List<double> samples) {
    _controller.add(samples);
  }
}

void main() {
  group('TunerViewModel', () {
    test('initialize with denied permission shows permissionRequired and does not start', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.denied,
      );
      final viewModel = TunerViewModel(audioInputService: service);

      await viewModel.initialize();

      expect(viewModel.state, TunerViewState.permissionRequired);
      expect(service.startCalls, 0);
      expect(viewModel.errorMessage, isNull);
    });

    test('initialize with granted permission records and updates level from samples', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final viewModel = TunerViewModel(audioInputService: service);

      await viewModel.initialize();

      expect(viewModel.state, TunerViewState.recording);
      expect(service.startCalls, 1);

      service.pushSamples([1, 1, 1, 1]);
      await pumpEventQueue();
      expect(viewModel.level, 1.0);

      service.pushSamples([0.5, 0.5, 0.5, 0.5]);
      await pumpEventQueue();
      expect(viewModel.level, 0.5);
    });

    test('initialize with permanentlyDenied shows permissionPermanentlyDenied', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.permanentlyDenied,
      );
      final viewModel = TunerViewModel(audioInputService: service);

      await viewModel.initialize();

      expect(viewModel.state, TunerViewState.permissionPermanentlyDenied);
      expect(service.startCalls, 0);
    });

    test('initialize with restricted shows permissionDenied with a message', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.restricted,
      );
      final viewModel = TunerViewModel(audioInputService: service);

      await viewModel.initialize();

      expect(viewModel.state, TunerViewState.permissionDenied);
      expect(viewModel.errorMessage, isNotNull);
      expect(service.startCalls, 0);
    });

    test('requestPermission after denial grants and starts recording', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.denied,
      );
      final viewModel = TunerViewModel(audioInputService: service);

      await viewModel.initialize();
      expect(viewModel.state, TunerViewState.permissionRequired);

      service.permissionState = MicrophonePermissionState.granted;
      await viewModel.requestPermission();

      expect(viewModel.state, TunerViewState.recording);
      expect(service.startCalls, 1);
    });

    test('requestPermission that stays denied returns to permissionRequired', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.denied,
      );
      final viewModel = TunerViewModel(audioInputService: service);

      await viewModel.requestPermission();

      expect(viewModel.state, TunerViewState.permissionRequired);
      expect(service.startCalls, 0);
    });

    test('initialize when start throws sets error state with message and no crash', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      service.throwOnStart = true;
      final viewModel = TunerViewModel(audioInputService: service);

      await viewModel.initialize();

      expect(viewModel.state, TunerViewState.error);
      expect(viewModel.errorMessage, isNotNull);
      expect(service.startCalls, 1);
    });

    test('stream errors set error state with message', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final viewModel = TunerViewModel(audioInputService: service);

      await viewModel.initialize();
      expect(viewModel.state, TunerViewState.recording);

      service._controller.addError(StateError('boom'));
      await pumpEventQueue();

      expect(viewModel.state, TunerViewState.error);
      expect(viewModel.errorMessage, contains('boom'));
    });

    test('stop cancels subscription so later pushes do not change level', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final viewModel = TunerViewModel(audioInputService: service);

      await viewModel.initialize();
      service.pushSamples([1, 1, 1, 1]);
      await pumpEventQueue();
      expect(viewModel.level, 1.0);

      await viewModel.stop();
      expect(viewModel.state, TunerViewState.loading);
      expect(service.stopCalls, 1);
      expect(viewModel.level, 0);

      service.pushSamples([0.5, 0.5, 0.5, 0.5]);
      await pumpEventQueue();
      expect(viewModel.level, 0);
    });

    test('initialize after stop restores recording without re-checking permission', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final viewModel = TunerViewModel(audioInputService: service);

      await viewModel.initialize();
      expect(service.checkPermissionCalls, 1);

      await viewModel.stop();

      await viewModel.initialize();

      expect(viewModel.state, TunerViewState.recording);
      expect(service.checkPermissionCalls, 1);
      expect(service.startCalls, 2);
    });
  });
}