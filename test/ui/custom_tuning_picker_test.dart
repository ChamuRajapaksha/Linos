import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linos/domain/models/tuning_preset.dart';
import 'package:linos/ui/core/theme/app_theme.dart';
import 'package:linos/ui/features/tuner/views/tuning_picker_sheet.dart';

TuningPreset customPreset(String id, String name) {
  return TuningPreset(
    id: id,
    name: name,
    notes: [
      TuningPreset.noteFor('E', 2),
      TuningPreset.noteFor('A', 2),
      TuningPreset.noteFor('D', 3),
      TuningPreset.noteFor('G', 3),
      TuningPreset.noteFor('B', 3),
      TuningPreset.noteFor('E', 4),
    ],
  );
}

void main() {
  Widget buildSheet({
    List<TuningPreset> presets = const [],
    String? selectedId,
    VoidCallback? onCreateCustom,
    ValueChanged<String>? onDeleteCustom,
  }) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: TuningPickerSheet(
          presets: [
            ...TuningPreset.all,
            ...presets,
          ],
          selectedId: selectedId ?? 'standard',
          onSelected: (_) {},
          onCreateCustom: onCreateCustom,
          onDeleteCustom: onDeleteCustom,
        ),
      ),
    );
  }

  testWidgets('hides the custom section when there are no customs', (tester) async {
    await tester.pumpWidget(buildSheet());
    expect(find.text('CUSTOM'), findsNothing);
    expect(find.text('NEW'), findsNothing);
  });

  testWidgets('shows a Custom section and New action when customs exist or '
      'creation is enabled', (tester) async {
    final created = <bool>[];
    await tester.pumpWidget(
      buildSheet(
        presets: [customPreset('custom-1-1', 'Drop C')],
        onCreateCustom: () => created.add(true),
      ),
    );

    expect(find.text('CUSTOM'), findsOneWidget);
    expect(find.text('DROP C'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);

    await tester.tap(find.text('NEW'));
    expect(created, [true]);
  });

  testWidgets('custom tuning delete button invokes onDeleteCustom',
      (tester) async {
    final deleted = <String>[];
    await tester.pumpWidget(
      buildSheet(
        presets: [customPreset('custom-9-9', 'Open C')],
        onDeleteCustom: (id) => deleted.add(id),
      ),
    );

    final deleteButton = find.descendant(
      of: find.byKey(const ValueKey('tuning-option-custom-9-9')),
      matching: find.byIcon(Icons.delete_outline),
    );
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);

    expect(deleted, ['custom-9-9']);
  });

  testWidgets('custom tuning shows the selected highlight when active',
      (tester) async {
    await tester.pumpWidget(
      buildSheet(
        presets: [customPreset('custom-5-5', 'Dadgad-ish')],
        selectedId: 'custom-5-5',
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tuning-option-custom-5-5')),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
  });
}
