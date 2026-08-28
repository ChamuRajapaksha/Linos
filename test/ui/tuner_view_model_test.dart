import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/services/audio_input_service.dart';
import 'package:linos/data/services/pitch_detection_service.dart';
import 'package:linos/data/services/record_audio_input_service.dart';
import 'package:linos/domain/models/frequency.dart';
import 'package:linos/domain/models/note.dart';
import 'package:linos/domain/models/pitch_detection.dart';
import 'package:linos/domain/models/tuning_status.dart';
import 'package:linos/domain/use_cases/string_matcher.dart';
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

class FakePitchDetectionService extends PitchDetectionService {
  FakePitchDetectionService(AudioInputService audioInputService)
      : super(audioInputService: audioInputService);

  final StreamController<PitchDetection> _controller =
      StreamController<PitchDetection>.broadcast();

  int startCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<PitchDetection> get pitchStream => _controller.stream;

  @override
  Future<void> start() async {
    startCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await stop();
  }

  void pushDetection(PitchDetection detection) {
    _controller.add(detection);
  }
}

PitchDetection detection({
  double frequency = 440.0,
  String name = 'A',
  int octave = 4,
  double centsOffset = 0.0,
  double confidence = 0.9,
  double rms = 0.5,
}) {
  return PitchDetection(
    frequency: Frequency(value: frequency),
    note: Note(name: name, octave: octave, frequency: frequency),
    centsOffset: centsOffset,
    confidence: confidence,
    rms: rms,
  );
}

void main() {
  group('TunerViewModel', () {
    test('initialize with denied permission shows permissionRequired and does not start', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.denied,
      );
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();

      expect(viewModel.state, TunerViewState.permissionRequired);
      expect(service.startCalls, 0);
      expect(viewModel.errorMessage, isNull);
    });

    test('initialize with granted permission records and updates level from samples', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

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
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();

      expect(viewModel.state, TunerViewState.permissionPermanentlyDenied);
      expect(service.startCalls, 0);
    });

    test('initialize with restricted shows permissionDenied with a message', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.restricted,
      );
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();

      expect(viewModel.state, TunerViewState.permissionDenied);
      expect(viewModel.errorMessage, isNotNull);
      expect(service.startCalls, 0);
    });

    test('requestPermission after denial grants and starts recording', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.denied,
      );
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

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
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

      await viewModel.requestPermission();

      expect(viewModel.state, TunerViewState.permissionRequired);
      expect(service.startCalls, 0);
    });

    test('initialize when start throws sets error state with message and no crash', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      service.throwOnStart = true;
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();

      expect(viewModel.state, TunerViewState.error);
      expect(viewModel.errorMessage, isNotNull);
      expect(service.startCalls, 1);
    });

    test('stream errors set error state with message', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

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
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

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
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();
      expect(service.checkPermissionCalls, 1);

      await viewModel.stop();

      await viewModel.initialize();

      expect(viewModel.state, TunerViewState.recording);
      expect(service.checkPermissionCalls, 1);
      expect(service.startCalls, 2);
    });

    test('pitch is null initially and updates from the pitch service', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final pitchService = FakePitchDetectionService(service);
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: pitchService,
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();

      expect(viewModel.state, TunerViewState.recording);
      expect(viewModel.pitch, isNull);
      expect(pitchService.startCalls, 1);

      pitchService.pushDetection(detection());
      await pumpEventQueue();

      expect(viewModel.pitch, isNotNull);
      expect(viewModel.pitch!.note.label, 'A4');
      expect(viewModel.pitch!.frequency.value, 440);
    });

    test('stop resets pitch and stops the pitch service', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final pitchService = FakePitchDetectionService(service);
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: pitchService,
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();
      pitchService.pushDetection(detection());
      await pumpEventQueue();
      expect(viewModel.pitch, isNotNull);

      await viewModel.stop();

      expect(viewModel.state, TunerViewState.loading);
      expect(viewModel.pitch, isNull);
      expect(pitchService.stopCalls, 1);
    });

    test('pitch detections after stop do not update the view model', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final pitchService = FakePitchDetectionService(service);
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: pitchService,
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();
      pitchService.pushDetection(detection());
      await pumpEventQueue();
      expect(viewModel.pitch!.frequency.value, 440);

      await viewModel.stop();
      expect(viewModel.pitch, isNull);

      pitchService.pushDetection(
        detection(frequency: 523.25, name: 'C', octave: 5),
      );
      await pumpEventQueue();

      expect(viewModel.pitch, isNull);
    });

    test('stringMatch is null initially', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();

      expect(viewModel.stringMatch, isNull);
    });

    test('stringMatch identifies an in-tune A2 open string', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final pitchService = FakePitchDetectionService(service);
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: pitchService,
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();
      pitchService.pushDetection(detection(frequency: 110.0, octave: 2));
      await pumpEventQueue();

      expect(viewModel.stringMatch, isNotNull);
      expect(viewModel.stringMatch!.stringIndex, 1);
      expect(viewModel.stringMatch!.targetNote.label, 'A2');
      expect(viewModel.stringMatch!.status, TuningStatus.inTune);
      expect(viewModel.stringMatch!.centsOffset.abs(), lessThan(0.5));
    });

    test('stringMatch identifies a flat A string below target', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final pitchService = FakePitchDetectionService(service);
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: pitchService,
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();
      pitchService.pushDetection(detection(frequency: 100.0, octave: 2));
      await pumpEventQueue();

      expect(viewModel.stringMatch!.stringIndex, 1);
      expect(viewModel.stringMatch!.status, TuningStatus.flat);
      expect(viewModel.stringMatch!.centsOffset, lessThan(0));
    });

    test('stringMatch identifies the low E string at 82.41 Hz', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final pitchService = FakePitchDetectionService(service);
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: pitchService,
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();
      pitchService.pushDetection(detection(frequency: 82.41, octave: 2));
      await pumpEventQueue();

      expect(viewModel.stringMatch!.stringIndex, 0);
      expect(viewModel.stringMatch!.targetNote.label, 'E2');
    });

    test('stop resets stringMatch and later detections do not update it', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final pitchService = FakePitchDetectionService(service);
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: pitchService,
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();
      pitchService.pushDetection(detection(frequency: 110.0, octave: 2));
      await pumpEventQueue();
      expect(viewModel.stringMatch, isNotNull);

      await viewModel.stop();
      expect(viewModel.stringMatch, isNull);

      pitchService.pushDetection(detection(frequency: 110.0, octave: 2));
      await pumpEventQueue();
      expect(viewModel.stringMatch, isNull);
    });

    test('selecting a string fixes the match to that string', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final pitchService = FakePitchDetectionService(service);
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: pitchService,
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();
      viewModel.selectString(0);
      expect(viewModel.selectedString, 0);

      pitchService.pushDetection(detection(frequency: 100.0, octave: 2));
      await pumpEventQueue();

      expect(viewModel.stringMatch, isNotNull);
      expect(viewModel.stringMatch!.stringIndex, 0);
      expect(viewModel.stringMatch!.targetNote.label, 'E2');
    });

    test('selecting a string reclassifies the existing pitch immediately',
        () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final pitchService = FakePitchDetectionService(service);
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: pitchService,
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();
      pitchService.pushDetection(detection(frequency: 100.0, octave: 2));
      await pumpEventQueue();
      expect(viewModel.stringMatch!.stringIndex, 1);

      viewModel.selectString(0);
      expect(viewModel.selectedString, 0);
      expect(viewModel.stringMatch!.stringIndex, 0);
      expect(viewModel.stringMatch!.targetNote.label, 'E2');
    });

    test('deselecting returns to auto string identification', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final pitchService = FakePitchDetectionService(service);
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: pitchService,
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();
      viewModel.selectString(0);
      viewModel.selectString(null);
      expect(viewModel.selectedString, isNull);

      pitchService.pushDetection(detection(frequency: 110.0, octave: 2));
      await pumpEventQueue();
      expect(viewModel.stringMatch!.stringIndex, 1);
    });

    test('tuning notes come from the configured tuning', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

      expect(viewModel.a4Reference, 440);
      expect(viewModel.tuningNotes.length, 6);
      expect(viewModel.tuningNotes[0].label, 'E2');
      expect(viewModel.tuningNotes[5].label, 'E4');
    });

    test('setReferencePitch retunes the string matcher', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final pitchService = FakePitchDetectionService(service);
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: pitchService,
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();
      viewModel.setReferencePitch(442);
      expect(viewModel.a4Reference, 442);
      expect(viewModel.tuningNotes[1].frequency, closeTo(110.0 * (442 / 440), 0.01));

      pitchService.pushDetection(detection(frequency: 110.5, octave: 2));
      await pumpEventQueue();
      expect(viewModel.stringMatch!.stringIndex, 1);
      expect(viewModel.stringMatch!.status, TuningStatus.inTune);
    });

    test('setReferencePitch ignores invalid and unchanged values', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

      viewModel.setReferencePitch(440);
      expect(viewModel.a4Reference, 440);
      viewModel.setReferencePitch(0);
      expect(viewModel.a4Reference, 440);
      viewModel.setReferencePitch(-5);
      expect(viewModel.a4Reference, 440);
    });

    test('selectTuning switches the matcher to the preset', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

      await viewModel.selectTuning('drop-d');

      expect(viewModel.tuningId, 'drop-d');
      expect(viewModel.tuningName, 'Drop D');
      expect(viewModel.tuningNotes[0].label, 'D2');
    });

    test('selectTuning ignores unknown ids', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

      await viewModel.selectTuning('nope');

      expect(viewModel.tuningId, 'standard');
      expect(viewModel.tuningNotes[0].label, 'E2');
    });

    test('selectTuning same id is a no-op', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

      await viewModel.selectTuning('drop-d');
      await viewModel.selectTuning('drop-d');

      expect(viewModel.tuningName, 'Drop D');
    });

    test('setReferencePitch retunes the active preset', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

      await viewModel.selectTuning('open-g');
      viewModel.setReferencePitch(442);

      expect(viewModel.tuningId, 'open-g');
      expect(
        viewModel.tuningNotes[0].frequency,
        closeTo(73.42 * (442 / 440), 0.01),
      );
    });

    test('switching tuning re-runs the latest pitch immediately', () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final pitchService = FakePitchDetectionService(service);
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: pitchService,
        stringMatcher: const StringMatcher(),
      );

      await viewModel.initialize();
      pitchService.pushDetection(detection(frequency: 82.41, octave: 2));
      await pumpEventQueue();

      expect(viewModel.stringMatch!.stringIndex, 0);
      expect(viewModel.stringMatch!.targetNote.label, 'E2');

      await viewModel.selectTuning('drop-d');

      expect(viewModel.stringMatch!.stringIndex, 0);
      expect(viewModel.stringMatch!.targetNote.label, 'D2');
    });

    test('selecting a different tuning keeps the tapped-string lock valid',
        () async {
      final service = FakeAudioInputService(
        permissionState: MicrophonePermissionState.granted,
      );
      final viewModel = TunerViewModel(
        audioInputService: service,
        pitchDetectionService: FakePitchDetectionService(service),
        stringMatcher: const StringMatcher(),
      );

      viewModel.selectString(4);
      await viewModel.selectTuning('drop-d');

      expect(viewModel.selectedString, 4);
    });
  });
}