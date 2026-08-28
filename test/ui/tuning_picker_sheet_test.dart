import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linos/domain/models/tuning_preset.dart';
import 'package:linos/ui/core/theme/app_theme.dart';
import 'package:linos/ui/features/tuner/views/tuning_picker_sheet.dart';

void main() {
  Widget buildSheet() {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: TuningPickerSheet(
          presets: TuningPreset.all,
          selectedId: 'standard',
          onSelected: (_) {},
        ),
      ),
    );
  }

  testWidgets('lists every preset', (tester) async {
    await tester.pumpWidget(buildSheet());

    for (final name in [
      'STANDARD',
      'DROP D',
      'HALF-STEP DOWN',
      'OPEN G',
      'OPEN D',
      'OPEN E',
      'DADGAD',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('highlights the selected preset', (tester) async {
    await tester.pumpWidget(buildSheet());

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tuning-option-standard')),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a preset moves the highlight locally without wiring',
      (tester) async {
    await tester.pumpWidget(buildSheet());

    await tester.tap(find.text('DROP D'));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tuning-option-drop-d')),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tuning-option-standard')),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsNothing,
    );
  });

  testWidgets('Done dismisses the sheet', (tester) async {
    await tester.pumpWidget(buildSheet());

    await tester.ensureVisible(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('CHOOSE TUNING'), findsNothing);
  });
}
