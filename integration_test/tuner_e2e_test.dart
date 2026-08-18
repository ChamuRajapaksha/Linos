import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:linos/data/services/pitch_detection_service.dart';
import 'package:linos/di/locator.dart';
import 'package:linos/ui/core/linos_app.dart';

/// On-device end-to-end soak for the tuner pipeline:
/// mic -> pitch detection -> string matching -> status.
///
/// Run on a real device with a guitar at hand:
///
///   flutter test integration_test/tuner_e2e_test.dart -d `<device>`
///
/// The test starts the app, waits for the operator to approve the system
/// microphone dialog, then soaks for 2 minutes. During the soak, strum each
/// open string (low E through high E) a few times so the pipeline sees real
/// harmonic-rich audio. After the soak the test asserts there were no errors,
/// the processing buffer stayed bounded, and memory did not grow unboundedly.
///
/// NOTE: this test must be run on a physical device (or an emulator that
/// provides a real mic feed); it cannot pass on the host.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Locator.init();
  });

  testWidgets(
    'tuner: mic -> detection -> string -> status with no backlog or leak',
    (tester) async {
      await tester.pumpWidget(const LinosApp());

      // The app requests mic permission lazily; approve the system dialog
      // when it appears so recording can start.
      final readyDeadline = DateTime.now().add(const Duration(seconds: 30));
      while (find.text('Play a string to tune').evaluate().isEmpty &&
          DateTime.now().isBefore(readyDeadline)) {
        if (find.text('Enable Microphone').evaluate().isNotEmpty) {
          await tester.tap(find.text('Enable Microphone'));
        }
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.text('Play a string to tune'), findsOneWidget,
          reason: 'recording should start once microphone permission is '
              'granted (approve the system dialog)');

      final pitchService = locator<PitchDetectionService>();
      final errors = <Object>[];
      var detections = 0;
      final subscription = pitchService.pitchStream.listen(
        (_) => detections++,
        onError: (Object error, StackTrace stackTrace) {
          errors.add('pitch stream: $error');
        },
      );
      addTearDown(subscription.cancel);

      FlutterErrorDetails? flutterError;
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        flutterError = details;
      };
      addTearDown(() => FlutterError.onError = previousOnError);

      // 2-minute continuous soak: monitor RSS and pipeline backpressure.
      final rssSamples = <int>[];
      final started = DateTime.now();
      const soak = Duration(minutes: 2);
      var exceptionCount = 0;
      while (DateTime.now().difference(started) < soak) {
        await tester.pump(const Duration(seconds: 5));
        rssSamples.add(ProcessInfo.currentRss);
        if (tester.takeException() != null) {
          exceptionCount++;
        }
      }

      // No errors surfaced from the UI or the processing pipeline.
      expect(errors, isEmpty, reason: 'pitch stream must stay error-free');
      expect(flutterError, isNull,
          reason: 'no Flutter error should be reported during the soak');
      expect(exceptionCount, 0,
          reason: 'no exceptions should escape the widget tree');

      // Backlog check: the sliding-window buffer must stay bounded even if the
      // detector (running in a compute isolate) momentarily falls behind.
      expect(
        pitchService.bufferedSampleCount,
        lessThan(pitchService.windowSize * 4),
        reason: 'audio buffer must not grow unboundedly during the soak',
      );

      // Memory growth check: compare the average RSS of the first vs last
      // thirds of the soak, allowing typical GC jitter (<= 32 MB growth).
      if (rssSamples.length >= 9) {
        final third = rssSamples.length ~/ 3;
        final firstAvg = rssSamples
                .sublist(0, third)
                .reduce((a, b) => a + b) /
            third;
        final lastAvg =
            rssSamples.sublist(rssSamples.length - third).reduce((a, b) => a + b) /
                third;
        expect(
          lastAvg - firstAvg,
          lessThan(32 * 1024 * 1024),
          reason:
              'RSS should not grow by more than 32 MB over a 2-minute soak '
              '(was ${(lastAvg - firstAvg) / (1024 * 1024)} MiB)',
        );
      }

      // Informational metrics for the operator/reference cross-check.
      // ignore: avoid_print
      print('integration: detections=$detections '
          'buffered=${pitchService.bufferedSampleCount} '
          'maxRssMiB=${rssSamples.reduce((a, b) => a > b ? a : b) / (1024 * 1024)}');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
