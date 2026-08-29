import 'package:flutter/material.dart';

import '../../../../domain/models/tuning_preset.dart';
import '../../../core/theme/linos_palette.dart';

class TuningPickerSheet extends StatefulWidget {
  const TuningPickerSheet({
    super.key,
    required this.presets,
    required this.selectedId,
    required this.onSelected,
    this.onCreateCustom,
    this.onDeleteCustom,
  });

  final List<TuningPreset> presets;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback? onCreateCustom;

  /// Called when a custom tuning's delete action is requested.
  final ValueChanged<String>? onDeleteCustom;

  static const String customIdPrefix = 'custom-';

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

    final List<TuningPreset> builtIns = [];
    final List<TuningPreset> customs = [];
    for (final preset in widget.presets) {
      if (preset.id.startsWith(TuningPickerSheet.customIdPrefix)) {
        customs.add(preset);
      } else {
        builtIns.add(preset);
      }
    }

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
            for (int i = 0; i < builtIns.length; i++) ...[
              _TuningOptionTile(
                preset: builtIns[i],
                selected: builtIns[i].id == _selectedId,
                onTap: () => _handleTap(builtIns[i].id),
                palette: palette,
                theme: theme,
              ),
              if (i < builtIns.length - 1) const SizedBox(height: 10),
            ],
            if (widget.onCreateCustom != null || customs.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'CUSTOM',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  if (widget.onCreateCustom != null)
                    _TextAction(
                      label: 'New',
                      onTap: widget.onCreateCustom!,
                      palette: palette,
                      theme: theme,
                    ),
                ],
              ),
              if (widget.onCreateCustom != null) const SizedBox(height: 10),
              for (int i = 0; i < customs.length; i++) ...[
                _TuningOptionTile(
                  preset: customs[i],
                  selected: customs[i].id == _selectedId,
                  onTap: () => _handleTap(customs[i].id),
                  onDelete: widget.onDeleteCustom == null
                      ? null
                      : () => widget.onDeleteCustom!(customs[i].id),
                  palette: palette,
                  theme: theme,
                ),
                if (i < customs.length - 1) const SizedBox(height: 10),
              ],
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
    this.onDelete,
  });

  final TuningPreset preset;
  final bool selected;
  final VoidCallback onTap;
  final LinosPalette palette;
  final ThemeData theme;
  final VoidCallback? onDelete;

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
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  if (onDelete != null)
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        onPressed: onDelete,
                        tooltip: 'Delete ${preset.name}',
                        icon: Icon(
                          Icons.delete_outline,
                          color: palette.textMuted,
                          size: 20,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  if (selected)
                    Icon(Icons.check_circle, color: palette.accent, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.onTap,
    required this.palette,
    required this.theme,
  });

  final String label;
  final VoidCallback onTap;
  final LinosPalette palette;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label custom tuning',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: palette.accent),
              const SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.accent,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
