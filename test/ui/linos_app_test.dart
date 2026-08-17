import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/services/audio_input_service.dart';
import 'package:linos/di/locator.dart';
import 'package:linos/ui/core/linos_app.dart';
import 'package:linos/ui/features/tuner/view_models/tuner_view_model.dart';

class FakeAudioInputService implements AudioInputService {
  FakeAudioInputService({
    this.permissionState = MicrophonePermissionState.denied,
  });

  MicrophonePermissionState permissionState;
  int startCalls = 0;
  int stopCalls = 0;

  final StreamController<List<double>> _controller =
      StreamController<List<double>>.broadcast();

  @override
  Stream<List<double>> get audioSamples => _controller.stream;

  @override
  Future<MicrophonePermissionState> checkPermission() async => permissionState;

  @override
  Future<MicrophonePermissionState> requestPermission() async => permissionState;

  @override
  Future<void> start() async {
    startCalls++;
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
  late FakeAudioInputService fake;

  setUp(() async {
    await locator.reset();
    fake = FakeAudioInputService();
    locator.registerSingleton<AudioInputService>(fake);
    Locator.init();
  });

  testWidgets('renders the Linos branding', (tester) async {
    await tester.pumpWidget(const LinosApp());

    expect(find.text('LINOS'), findsOneWidget);
  });

  testWidgets('shows the enable microphone prompt when permission is denied',
      (tester) async {
    await tester.pumpWidget(const LinosApp());
    await tester.pump();

    expect(find.text('Enable Microphone'), findsOneWidget);
  });

  testWidgets('granting permission starts recording and shows live level',
      (tester) async {
    await tester.pumpWidget(const LinosApp());
    await tester.pump();
    expect(find.text('Enable Microphone'), findsOneWidget);

    fake.permissionState = MicrophonePermissionState.granted;
    await tester.tap(find.text('Enable Microphone'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Play a string to tune'), findsOneWidget);

    fake.pushSamples([0.8, 0.8, 0.8, 0.8]);
    await tester.pump();
    await tester.pump();

    expect(find.text('080%'), findsOneWidget);
  });

  test('TunerViewModel is resolvable from the locator', () {
    expect(locator<TunerViewModel>(), isA<TunerViewModel>());
  });
}