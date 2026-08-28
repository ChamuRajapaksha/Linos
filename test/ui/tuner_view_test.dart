import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/services/audio_input_service.dart';
import 'package:linos/data/services/pitch_detection_service.dart';
import 'package:linos/domain/models/frequency.dart';
import 'package:linos/domain/models/note.dart';
import 'package:linos/domain/models/pitch_detection.dart';
import 'package:linos/domain/use_cases/string_matcher.dart';
import 'package:linos/ui/core/theme/app_theme.dart';
import 'package:linos/ui/features/tuner/view_models/tuner_view_model.dart';
import 'package:linos/ui/features/tuner/views/tuner_view.dart';
import 'package:linos/ui/features/tuner/views/tuning_picker_sheet.dart';

class FakeAudioInputService implements AudioInputService {
  FakeAudioInputService({
    this.permissionState = MicrophonePermissionState.granted,
  });

  MicrophonePermissionState permissionState;

  final StreamController<List<double>> _controller =
      StreamController<List<double>>.broadcast();

  @override
  Stream<List<double>> get audioSamples => _controller.stream;

  @override
  Future<MicrophonePermissionState> checkPermission() async => permissionState;

  @override
  Future<MicrophonePermissionState> requestPermission() async => permissionState;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

class FakePitchDetectionService extends PitchDetectionService {
  FakePitchDetectionService(AudioInputService audioInputService)
      : super(audioInputService: audioInputService);

  final StreamController<PitchDetection> _controller =
      StreamController<PitchDetection>.broadcast();

  @override
  Stream<PitchDetection> get pitchStream => _controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  void pushDetection(PitchDetection detection) {
    _controller.add(detection);
  }
}

PitchDetection detection({
  double frequency = 440.0,
  String name = 'A',
  int octave = 4,
}) {
  return PitchDetection(
    frequency: Frequency(value: frequency),
    note: Note(name: name, octave: octave, frequency: frequency),
    centsOffset: 0,
    confidence: 0.9,
    rms: 0.5,
  );
}

Future<TunerViewModel> pumpTuner(
  WidgetTester tester, {
  FakePitchDetectionService? pitchService,
}) async {
  final service = FakeAudioInputService();
  final pitch = pitchService ?? FakePitchDetectionService(service);
  final viewModel = TunerViewModel(
    audioInputService: service,
    pitchDetectionService: pitch,
    stringMatcher: const StringMatcher(),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: TunerView(viewModel: viewModel),
    ),
  );
  await tester.pump();
  await tester.pump();
  return viewModel;
}

void main() {
  testWidgets('recording screen shows the string rail with all six notes',
      (tester) async {
    await pumpTuner(tester);

    expect(find.text('E'), findsNWidgets(2));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('AUTO'), findsOneWidget);
    expect(find.text('Play a string to tune'), findsOneWidget);
  });

  testWidgets('a detected pitch lights the string rail and hero note',
      (tester) async {
    final pitch = FakePitchDetectionService(FakeAudioInputService());
    final viewModel = await pumpTuner(tester, pitchService: pitch);

    pitch.pushDetection(detection(frequency: 110.0, octave: 2));
    await tester.pump();
    await tester.pump();

    expect(viewModel.stringMatch!.stringIndex, 1);
    expect(find.text('A'), findsNWidgets(2));
    expect(find.text('5TH STRING · A2'), findsOneWidget);
    expect(find.textContaining('IN TUNE'), findsWidgets);
    expect(find.text('Listening…'), findsOneWidget);
  });

  testWidgets('tapping a string focuses tuning on it', (tester) async {
    final viewModel = await pumpTuner(tester);

    await tester.tap(find.text('D'));
    await tester.pump();
    await tester.pump();

    expect(viewModel.selectedString, 2);
    expect(find.text('4TH'), findsOneWidget);

    await tester.tap(find.text('D'));
    await tester.pump();

    expect(viewModel.selectedString, isNull);
    expect(find.text('AUTO'), findsOneWidget);
  });

  testWidgets('settings sheet changes the reference pitch', (tester) async {
    final pitch = FakePitchDetectionService(FakeAudioInputService());
    final viewModel = await pumpTuner(tester, pitchService: pitch);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('TUNER SETTINGS'), findsOneWidget);

    await tester.tap(find.text('442'));
    await tester.pumpAndSettle();

    expect(viewModel.a4Reference, 442);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('TUNER SETTINGS'), findsNothing);
  });

  testWidgets('selecting a tuning from the picker wires into the view model',
      (tester) async {
    final viewModel = await pumpTuner(tester);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('STANDARD ·'));
    await tester.pumpAndSettle();

    expect(find.text('CHOOSE TUNING'), findsOneWidget);
    expect(find.text('DADGAD'), findsOneWidget);

    await tester.tap(find.text('DROP D'));
    await tester.pumpAndSettle();

    final doneInPicker = find.descendant(
      of: find.byType(TuningPickerSheet),
      matching: find.text('Done'),
    );
    await tester.ensureVisible(doneInPicker);
    await tester.pumpAndSettle();
    await tester.tap(doneInPicker);
    await tester.pumpAndSettle();

    expect(viewModel.tuningId, 'drop-d');
    expect(viewModel.tuningName, 'Drop D');
  });

  testWidgets('string rail re-renders on tuning selection', (tester) async {
    final viewModel = await pumpTuner(tester);

    expect(find.text('E'), findsNWidgets(2));
    expect(find.text('D'), findsOneWidget);

    await viewModel.selectTuning('drop-d');
    await tester.pump();

    expect(find.text('D'), findsNWidgets(2));
    expect(find.text('E'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('AUTO'), findsOneWidget);
  });

  testWidgets('active tuning name shows on the tuner screen and opens the picker',
      (tester) async {
    final viewModel = await pumpTuner(tester);

    expect(find.text('STANDARD'), findsOneWidget);

    await viewModel.selectTuning('drop-d');
    await tester.pump();

    expect(find.text('DROP D'), findsOneWidget);

    await tester.tap(find.text('DROP D'));
    await tester.pumpAndSettle();

    expect(find.text('CHOOSE TUNING'), findsOneWidget);
  });

  testWidgets('reference pitch shift moves the in-tune point', (tester) async {
    final pitch = FakePitchDetectionService(FakeAudioInputService());
    final viewModel = await pumpTuner(tester, pitchService: pitch);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('442'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    pitch.pushDetection(detection(frequency: 110.5, octave: 2));
    await tester.pump();
    await tester.pump();

    expect(viewModel.stringMatch!.stringIndex, 1);
    expect(viewModel.stringMatch!.status.name, 'inTune');
    expect(find.textContaining('IN TUNE'), findsWidgets);
  });
}
