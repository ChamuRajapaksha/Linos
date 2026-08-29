import 'package:flutter/material.dart';

import '../../../../domain/models/note.dart';
import '../../../../domain/models/tuning_preset.dart';
import '../../../../domain/use_cases/custom_tuning_validator.dart';
import '../view_models/tuner_view_model.dart';
import '../../../core/theme/linos_palette.dart';

class CustomTuningSheet extends StatefulWidget {
  const CustomTuningSheet({super.key, required this.viewModel});

  final TunerViewModel viewModel;

  @override
  State<CustomTuningSheet> createState() => _CustomTuningSheetState();
}

class _CustomTuningSheetState extends State<CustomTuningSheet> {
  static const List<String> _ordinals = [
    '6th',
    '5th',
    '4th',
    '3rd',
    '2nd',
    '1st',
  ];

  final TextEditingController _nameController = TextEditingController();
  late final List<_StringEntry> _strings = List.generate(6, (i) {
    return _StringEntry(
      note: _initialNote(i),
      octave: _initialOctave(i),
    );
  });

  String? _nameError;
  Map<int, String> _stringErrors = {};

  static String _initialNote(int stringIndex) {
    const preferred = ['D', 'A', 'D', 'G', 'B', 'E'];
    return preferred[stringIndex];
  }

  static int _initialOctave(int stringIndex) {
    const preferred = [2, 2, 3, 3, 3, 4];
    return preferred[stringIndex];
  }

  void _validateAndSave() async {
    final notes = [
      for (final entry in _strings)
        TuningPreset.noteFor(entry.note, entry.octave),
    ];
    final validation = widget.viewModel.validateCustomTuning(
      name: _nameController.text,
      notes: notes,
    );
    setState(() {
      _nameError = validation.nameError;
      _stringErrors = validation.stringErrors;
    });
    if (!validation.isValid) {
      return;
    }
    final preset = await widget.viewModel.saveCustomTuning(
      name: _nameController.text.trim(),
      notes: notes,
    );
    if (preset == null || !mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              container: true,
              excludeSemantics: true,
              label: 'Create custom tuning',
              child: Text('CUSTOM TUNING', style: theme.textTheme.labelLarge),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick a note and octave for each of the six strings.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Drop C',
                errorText: _nameError,
                errorMaxLines: 2,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'STRINGS',
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _strings.length; i++) ...[
              _StringEditorRow(
                key: ValueKey('custom-string-$i'),
                ordinal: _ordinals[i],
                note: _strings[i].note,
                octave: _strings[i].octave,
                error: _stringErrors[i],
                onNoteChanged: (value) {
                  setState(() => _strings[i].note = value);
                  if (_stringErrors.containsKey(i)) {
                    setState(() => _stringErrors = {});
                  }
                },
                onOctaveChanged: (value) {
                  setState(() => _strings[i].octave = value);
                  if (_stringErrors.containsKey(i)) {
                    setState(() => _stringErrors = {});
                  }
                },
                palette: palette,
                theme: theme,
              ),
              if (i < _strings.length - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _validateAndSave,
              child: const Text('Save Tuning'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StringEntry {
  _StringEntry({required this.note, required this.octave});

  String note;
  int octave;
}

class _StringEditorRow extends StatelessWidget {
  const _StringEditorRow({
    super.key,
    required this.ordinal,
    required this.note,
    required this.octave,
    required this.error,
    required this.onNoteChanged,
    required this.onOctaveChanged,
    required this.palette,
    required this.theme,
  });

  final String ordinal;
  final String note;
  final int octave;
  final String? error;
  final ValueChanged<String> onNoteChanged;
  final ValueChanged<int> onOctaveChanged;
  final LinosPalette palette;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: '$ordinal string, note $note, octave $octave',
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  ordinal.toUpperCase(),
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: palette.textMuted),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: note,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Note',
                  ),
                  items: [
                    for (final n in Note.chromaticNotes)
                      DropdownMenuItem(value: n, child: Text(n)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onNoteChanged(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                child: DropdownButtonFormField<int>(
                  initialValue: octave,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Octave',
                  ),
                  items: [
                    for (var o = CustomTuningValidator.minOctave;
                        o <= CustomTuningValidator.maxOctave;
                        o++)
                      DropdownMenuItem(value: o, child: Text('$o')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onOctaveChanged(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Text(
              error!,
              style: theme.textTheme.labelSmall?.copyWith(color: palette.sharp),
            ),
          ),
        ],
      ],
    );
  }
}
