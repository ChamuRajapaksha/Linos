import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/services/audio_input_service.dart';
import 'package:linos/data/services/pitch_detection_service.dart';
import 'package:linos/domain/models/pitch_detection.dart';
import 'package:linos/domain/use_cases/string_matcher.dart';
import 'package:linos/ui/core/theme/app_theme.dart';
import 'package:linos/ui/features/tuner/view_models/tuner_view_model.dart';
import 'package:linos/ui/features/tuner/views/custom_tuning_sheet.dart';

class FakeAudioInputService implements AudioInputService {
  final StreamController<List<double>> _samples =
      StreamController<List<double>>.broadcast();

  @override
  Stream<List<double>> get audioSamples => _samples.stream;

  @override
  Future<MicrophonePermissionState> checkPermission() async =>
      MicrophonePermissionState.granted;

  @override
  Future<MicrophonePermissionState> requestPermission() async =>
      MicrophonePermissionState.granted;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

class FakePitchDetectionService extends PitchDetectionService {
  FakePitchDetectionService(AudioInputService input)
      : super(audioInputService: input);

  final StreamController<PitchDetection> _stream =
      StreamController<PitchDetection>.broadcast();

  @override
  Stream<PitchDetection> get pitchStream => _stream.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

void main() {
  TunerViewModel buildViewModel() {
    final audio = FakeAudioInputService();
    return TunerViewModel(
      audioInputService: audio,
      pitchDetectionService: FakePitchDetectionService(audio),
      stringMatcher: const StringMatcher(),
    );
  }

  Widget buildSheet(TunerViewModel vm) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => CustomTuningSheet(viewModel: vm),
            ),
            child: const Text('open'),
          ),
        ),
      )),
    );
  }

  testWidgets('renders a name field and six string rows', (tester) async {
    final vm = buildViewModel();
    await tester.pumpWidget(buildSheet(vm));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('CUSTOM TUNING'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    for (final ordinal in ['6TH', '5TH', '4TH', '3RD', '2ND', '1ST']) {
      expect(find.text(ordinal), findsOneWidget);
    }
    expect(find.text('Save Tuning'), findsOneWidget);
  });

  testWidgets('shows a name error when saving with no name', (tester) async {
    final vm = buildViewModel();
    await tester.pumpWidget(buildSheet(vm));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save Tuning'));
    await tester.tap(find.text('Save Tuning'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a tuning name.'), findsOneWidget);
  });

  testWidgets('saving a named six-string tuning persists it', (tester) async {
    final vm = buildViewModel();
    await tester.pumpWidget(buildSheet(vm));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Drop C');
    await tester.ensureVisible(find.text('Save Tuning'));
    await tester.tap(find.text('Save Tuning'));
    await tester.pumpAndSettle();

    expect(vm.tuningPresets.any((p) => p.name == 'Drop C'), isTrue);
    expect(find.text('CUSTOM TUNING'), findsNothing);
  });
}
