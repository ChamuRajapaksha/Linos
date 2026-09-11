import 'package:flutter/material.dart';

import '../../../core/theme/linos_palette.dart';
import '../../../../data/models/chord_shape.dart';

Future<void> showChordDiagram(
  BuildContext context, {
  required String chordName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => _ChordDiagramSheet(chordName: chordName),
  );
}

class _ChordDiagramSheet extends StatelessWidget {
  const _ChordDiagramSheet({required this.chordName});

  final String chordName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LinosPalette palette = LinosPalette.forBrightness(theme.brightness);
    final ChordShape? shape = chordShapes[chordName];

    return Semantics(
      container: true,
      label: 'Chord diagram, $chordName',
      child: ExcludeSemantics(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  chordName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 16),
                if (shape != null)
                  SizedBox(
                    height: 190,
                    child: CustomPaint(
                      key: const ValueKey('chord-fretboard'),
                      painter: _FretboardPainter(
                        shape: shape,
                        palette: palette,
                      ),
                      size: const Size(double.infinity, 190),
                    ),
                  )
                else ...[
                  Icon(Icons.music_note, size: 48, color: palette.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'Diagram not available yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FretboardPainter extends CustomPainter {
  _FretboardPainter({required this.shape, required this.palette});

  final ChordShape shape;
  final LinosPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const int stringCount = 6;
    const int fretRows = 5;

    final double leftPad = 24;
    final double rightPad = 24;
    final double topPad = 28;
    final double bottomPad = 16;

    final double width = size.width - leftPad - rightPad;
    final double height = size.height - topPad - bottomPad;

    final double stringSpacing = width / (stringCount - 1);
    final double fretSpacing = height / fretRows;

    double xForString(int i) => leftPad + i * stringSpacing;
    double yForFret(int fret) => topPad + fret * fretSpacing;

    final bool hasBarre = _findBarreStrings(shape.frets);

    // Draw nut (thick top line) or first fret line.
    final Paint nutPaint = Paint()
      ..color = palette.panelBorder
      ..strokeWidth = shape.baseFret == 1 ? 4 : 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(leftPad, topPad),
      Offset(leftPad + width, topPad),
      nutPaint,
    );

    // Draw frets.
    final Paint fretPaint = Paint()
      ..color = palette.panelBorder
      ..strokeWidth = 1.5;
    for (int f = 1; f < fretRows; f++) {
      final double y = yForFret(f);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + width, y),
        fretPaint,
      );
    }

    // Draw strings.
    final Paint stringPaint = Paint()
      ..color = palette.panelBorder
      ..strokeWidth = 1.2;
    for (int s = 0; s < stringCount; s++) {
      final double x = xForString(s);
      canvas.drawLine(
        Offset(x, topPad),
        Offset(x, yForFret(fretRows)),
        stringPaint,
      );
    }

    final Paint dotPaint = Paint()..color = palette.accent;
    final Paint openPaint = Paint()
      ..color = palette.textMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final Paint mutedPaint = Paint()
      ..color = palette.textMuted
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (int s = 0; s < stringCount; s++) {
      final int fret = shape.frets[s];
      final double x = xForString(s);

      if (fret == 0) {
        // Open string: circle above the nut.
        canvas.drawCircle(
          Offset(x, topPad - 14),
          5,
          openPaint,
        );
      } else if (fret == -1) {
        // Muted: 'x' above the nut.
        const double arm = 4;
        final Offset center = Offset(x, topPad - 14);
        canvas.drawLine(
          center - const Offset(arm, arm),
          center + const Offset(arm, arm),
          mutedPaint,
        );
        canvas.drawLine(
          center - Offset(-arm, arm),
          center + Offset(-arm, arm),
          mutedPaint,
        );
      } else {
        // Fretted: dot in the appropriate row.
        final int row = fret - shape.baseFret;
        if (row >= 0 && row < fretRows) {
          final double cx = x;
          final double cy = yForFret(row) + fretSpacing / 2;
          canvas.drawCircle(Offset(cx, cy), 7, dotPaint);
        }
      }
    }

    // Draw barre.
    if (hasBarre) {
      _drawBarre(canvas, shape, stringSpacing, fretSpacing, leftPad, topPad, fretRows, palette);
    }
  }

  bool _findBarreStrings(List<int> frets) {
    final Map<int, List<int>> groups = {};
    for (int i = 0; i < frets.length; i++) {
      final int f = frets[i];
      if (f > 0) {
        groups.putIfAbsent(f, () => []).add(i);
      }
    }
    // A barre is when multiple non-adjacent or adjacent strings share the same fret,
    // and that fret equals the minimum non-zero fret.
    final int minFret = frets.where((f) => f > 0).fold<int>(
      999,
      (a, b) => a < b ? a : b,
    );
    final List<int> barreStrings = groups[minFret] ?? [];
    return barreStrings.length >= 2;
  }

  void _drawBarre(
    Canvas canvas,
    ChordShape shape,
    double stringSpacing,
    double fretSpacing,
    double leftPad,
    double topPad,
    int fretRows,
    LinosPalette palette,
  ) {
    final Map<int, List<int>> groups = {};
    for (int i = 0; i < shape.frets.length; i++) {
      final int f = shape.frets[i];
      if (f > 0) {
        groups.putIfAbsent(f, () => []).add(i);
      }
    }
    final int barreFret = groups.keys.where((f) => (groups[f]?.length ?? 0) >= 2).fold<int>(
      999,
      (a, b) => a < b ? a : b,
    );
    final List<int> barreStrings = groups[barreFret] ?? [];
    if (barreStrings.length < 2) return;

    barreStrings.sort();
    final int first = barreStrings.first;
    final int last = barreStrings.last;

    final int row = barreFret - shape.baseFret;
    if (row < 0 || row >= fretRows) return;

    final double y = topPad + row * fretSpacing + fretSpacing / 2;
    final double x1 = leftPad + first * stringSpacing;
    final double x2 = leftPad + last * stringSpacing;

    final Paint barrePaint = Paint()
      ..color = palette.accent
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x1, y), Offset(x2, y), barrePaint);
  }

  @override
  bool shouldRepaint(_FretboardPainter oldDelegate) {
    return oldDelegate.shape.name != shape.name ||
        oldDelegate.shape.baseFret != shape.baseFret ||
        oldDelegate.shape.frets != shape.frets;
  }
}
