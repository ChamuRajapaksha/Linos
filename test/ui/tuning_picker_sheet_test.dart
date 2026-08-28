import 'dart:ui';

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

  group('accessibility', () {
    testWidgets(
        'selected option exposes button, selected and label semantics',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildSheet());

      final selectedNode = tester.getSemantics(
        find.byKey(const ValueKey('tuning-option-standard')),
      );
      expect(selectedNode.flagsCollection.isButton, isTrue);
      expect(selectedNode.flagsCollection.isSelected, Tristate.isTrue);
      expect(
        selectedNode
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(find.bySemanticsLabel('Standard tuning'), findsOneWidget);

      final unselectedNode = tester.getSemantics(
        find.byKey(const ValueKey('tuning-option-drop-d')),
      );
      expect(unselectedNode.flagsCollection.isButton, isTrue);
      expect(
        unselectedNode.flagsCollection.isSelected,
        isNot(Tristate.isTrue),
      );
      expect(find.bySemanticsLabel('Drop D tuning'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('the header exposes a "Choose tuning" heading', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildSheet());

      final node = tester.getSemantics(find.text('CHOOSE TUNING'));
      expect(node.flagsCollection.isHeader, isTrue);
      expect(find.bySemanticsLabel('Choose tuning'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('visual labels are excluded from the option semantics',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildSheet());

      expect(find.bySemanticsLabel('Standard tuning'), findsOneWidget);
      expect(find.bySemanticsLabel('STANDARD'), findsNothing);
      expect(find.bySemanticsLabel('Drop D tuning'), findsOneWidget);

      handle.dispose();
    });
  });
}
