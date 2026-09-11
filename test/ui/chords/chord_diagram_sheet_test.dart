import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linos/ui/core/theme/app_theme.dart';
import 'package:linos/ui/features/chords/views/chord_diagram_sheet.dart';

Future<void> _openSheet(WidgetTester tester, String chord) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showChordDiagram(ctx, chordName: chord),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('known chord shows title and CustomPaint fretboard', (
    tester,
  ) async {
    await _openSheet(tester, 'C');

    expect(find.text('C'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byKey(const ValueKey('chord-fretboard')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('known chord exposes semantics label', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _openSheet(tester, 'C');

    expect(find.bySemanticsLabel('Chord diagram, C'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('unknown chord shows fallback message', (tester) async {
    await _openSheet(tester, 'X9');

    expect(find.text('Diagram not available yet'), findsOneWidget);
    expect(find.text('X9'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byKey(const ValueKey('chord-fretboard')),
      ),
      findsNothing,
    );
  });
}