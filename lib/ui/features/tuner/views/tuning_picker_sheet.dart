import 'package:flutter/material.dart';

import '../../../../domain/models/tuning_preset.dart';
import '../../../core/theme/linos_palette.dart';

class TuningPickerSheet extends StatefulWidget {
  const TuningPickerSheet({
    super.key,
    required this.presets,
    required this.selectedId,
    required this.onSelected,
  });

  final List<TuningPreset> presets;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  State<TuningPickerSheet> createState() => _TuningPickerSheetState();
}

class _TuningPickerSheetState extends State<TuningPickerSheet> {
  late String _selectedId = widget.selectedId;

  void _handleTap(String id) {
    setState(() => _selectedId = id);
    widget.onSelected(id);
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
              label: 'Choose tuning',
              child:
                  Text('CHOOSE TUNING', style: theme.textTheme.labelLarge),
            ),
            const SizedBox(height: 4),
            Text(
              'Presets for a six-string guitar.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < widget.presets.length; i++) ...[
              _TuningOptionTile(
                preset: widget.presets[i],
                selected: widget.presets[i].id == _selectedId,
                onTap: () => _handleTap(widget.presets[i].id),
                palette: palette,
                theme: theme,
              ),
              if (i < widget.presets.length - 1)
                const SizedBox(height: 10),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TuningOptionTile extends StatelessWidget {
  const _TuningOptionTile({
    required this.preset,
    required this.selected,
    required this.onTap,
    required this.palette,
    required this.theme,
  });

  final TuningPreset preset;
  final bool selected;
  final VoidCallback onTap;
  final LinosPalette palette;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey('tuning-option-${preset.id}'),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${preset.name} tuning',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ExcludeSemantics(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: selected
                    ? palette.accent.withValues(alpha: 0.18)
                    : palette.panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? palette.accent : palette.panelBorder,
                  width: selected ? 1.6 : 1,
                ),
              ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preset.name.toUpperCase(),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color:
                                  selected ? palette.accent : palette.text,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preset.notes.map((n) => n.name).join('\u2013'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle,
                          color: palette.accent, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }
}
