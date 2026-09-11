import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/repositories/song_search_repository.dart';
import 'package:linos/data/services/audio_input_service.dart';
import 'package:linos/data/services/pitch_detection_service.dart';
import 'package:linos/domain/models/pitch_detection.dart';
import 'package:linos/domain/models/song.dart';
import 'package:linos/domain/use_cases/string_matcher.dart';
import 'package:linos/ui/core/navigation/app_shell.dart';
import 'package:linos/ui/core/theme/app_theme.dart';
import 'package:linos/ui/features/chords/view_models/song_search_view_model.dart';
import 'package:linos/ui/features/tuner/view_models/tuner_view_model.dart';

/// A stream with no events and no done event whose subscriptions cancel
/// synchronously. StreamController-backed fakes leak unresolved cancel
/// futures under the widget-test FakeAsync clock when cancellation is driven
/// from an unawaited async callback (as TunerView.dispose does), so the
/// micro-stop guarantee can't be observed with them.
class _SilentStream<T> implements Stream<T> {
  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _SilentSubscription<T>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName} is not used in tests.');
  }
}

class _SilentSubscription<T> implements StreamSubscription<T> {
  @override
  Future<void> cancel() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName} is not used in tests.');
  }
}

class FakeAudioInputService implements AudioInputService {
  FakeAudioInputService({
    this.permissionState = MicrophonePermissionState.granted,
  });

  MicrophonePermissionState permissionState;
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Stream<List<double>> get audioSamples => _SilentStream<List<double>>();

  @override
  Future<MicrophonePermissionState> checkPermission() async => permissionState;

  @override
  Future<MicrophonePermissionState> requestPermission() async =>
      permissionState;

  @override
  Future<void> start() async {
    startCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

class FakePitchDetectionService extends PitchDetectionService {
  FakePitchDetectionService(AudioInputService audioInputService)
      : super(audioInputService: audioInputService);

  @override
  Stream<PitchDetection> get pitchStream => _SilentStream<PitchDetection>();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

class FakeSongSearchRepository implements SongSearchRepository {
  @override
  Future<List<Song>> search(String query) async => const [];
}

Future<void> pumpShell(
  WidgetTester tester, {
  required FakeAudioInputService audio,
  required TunerViewModel tunerViewModel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: AppShell(
        tunerViewModel: tunerViewModel,
        searchViewModel:
            SongSearchViewModel(repository: FakeSongSearchRepository()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('both navigation destinations render', (tester) async {
    final audio = FakeAudioInputService();
    final tunerViewModel = TunerViewModel(
      audioInputService: audio,
      pitchDetectionService: FakePitchDetectionService(audio),
      stringMatcher: const StringMatcher(),
    );
    await pumpShell(tester, audio: audio, tunerViewModel: tunerViewModel);

    final navBar = find.byType(NavigationBar);
    expect(
      find.descendant(of: navBar, matching: find.byIcon(Icons.tune)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.byIcon(Icons.music_note)),
      findsOneWidget,
    );
  });

  testWidgets('default shows the tuner tab', (tester) async {
    final audio = FakeAudioInputService();
    final tunerViewModel = TunerViewModel(
      audioInputService: audio,
      pitchDetectionService: FakePitchDetectionService(audio),
      stringMatcher: const StringMatcher(),
    );
    await pumpShell(tester, audio: audio, tunerViewModel: tunerViewModel);

    expect(find.text('Play a string to tune'), findsOneWidget);
    expect(find.text('Search by title or artist'), findsNothing);
  });

  testWidgets('switching to Chords stops the mic and shows the search screen',
      (tester) async {
    final audio = FakeAudioInputService();
    final tunerViewModel = TunerViewModel(
      audioInputService: audio,
      pitchDetectionService: FakePitchDetectionService(audio),
      stringMatcher: const StringMatcher(),
    );
    await pumpShell(tester, audio: audio, tunerViewModel: tunerViewModel);

    expect(find.text('Play a string to tune'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.music_note));
    await tester.pump();

    expect(find.text('Search by title or artist'), findsOneWidget);
    expect(find.text('Play a string to tune'), findsNothing);
    expect(audio.stopCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('switching back to Tuner restarts capture', (tester) async {
    final audio = FakeAudioInputService();
    final tunerViewModel = TunerViewModel(
      audioInputService: audio,
      pitchDetectionService: FakePitchDetectionService(audio),
      stringMatcher: const StringMatcher(),
    );
    await pumpShell(tester, audio: audio, tunerViewModel: tunerViewModel);

    final startCallsBefore = audio.startCalls;

    await tester.tap(find.byIcon(Icons.music_note));
    await tester.pump();

    expect(audio.stopCalls, greaterThanOrEqualTo(1));

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pump();
    await tester.pump();

    expect(find.text('Play a string to tune'), findsOneWidget);
    expect(audio.startCalls, greaterThan(startCallsBefore));
  });
}