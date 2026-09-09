# Linos Design System

Linos is an instrument-themed guitar tuner. The visual identity is guitar-shop
walnut and ebony surfaces with a brass accent, and directional status colors
that mirror the physics of tuning. Everything below is implemented in code and
is the source of truth:

- `lib/ui/core/theme/linos_palette.dart` — design tokens
- `lib/ui/core/theme/app_theme.dart` — Material 3 `ThemeData` builders
- `lib/ui/core/haptics/haptic_feedback.dart` — tactile feedback helper
- `lib/ui/features/tuner/views/` — the screens and components

## Palette

Fetch tokens anywhere with `LinosPalette.forBrightness(theme.brightness)`.

### Dark (default)

| Token        | Hex        | Use                                        |
|--------------|------------|--------------------------------------------|
| `background` | `0xFF15110C` | Scaffold, walnut ebony                    |
| `panel`      | `0xFF1E1913` | Panels, sheets, inputs                     |
| `panelBorder`| `0xFF30281F` | Hairline borders                          |
| `text`       | `0xFFF0E7D8` | Primary text                              |
| `textMuted`  | `0xFFA2947E` | Secondary text, inactive states           |
| `accent`     | `0xFFD29A3C` | Brass — highlights, active, selection     |
| `onAccent`   | `0xFF211A0E` | Text/icon on brass                        |
| `inTune`     | `0xFF43B27C` | Emerald — in tune                         |
| `flat`       | `0xFF7FA7C7` | Slate — flat                              |
| `sharp`      | `0xFFE08A4A` | Ember — sharp (also destructive actions)  |

### Light

`background 0xFFF5F0E6`, `panel 0xFFECE4D6`, `panelBorder 0xFFD9CFBC`,
`text 0xFF241D13`, `textMuted 0xFF6E6353`, `accent 0xFFA8721E`,
`onAccent 0xFFFAF5EA`, `inTune 0xFF2E7D55`, `flat 0xFF4A7BA3`, `sharp 0xFFB95C2A`.

## Status semantics

Tuning state is always one color: `flat` / `inTune` / `sharp` map to
`TuningStatusColor` and drive the hero note, needle, string rail and status
text together — never independently.

`sharp` also doubles as the destructive/emphasis color for confirm dialogs.

## Shape

- Panels: 10–18 px radii with a `panelBorder` border on `panel`.
- Inputs: 12 px rounded filled `OutlineInputBorder`, 2 px brass focus.
- Primary buttons: `FilledButton`, 14 px radius, `labelLarge` text.
- Chips/pills/indicators: fully rounded (20–24 px), brass at 14–18 % alpha
  background with a 50–60 % alpha border on selection.

## Typography

- Section headers: uppercase micro-labels, `labelLarge` (tracking 2.5) or
  `labelMedium` (tracking 1.5).
- Reinforced labels: `labelSmall` with tracking 2–3, e.g. STRINGS, AUTO,
  CHOOSE TUNING, PREPARING AUDIO.
- Hero note readout: 96 px, weight 800, tracking −3, `displayMedium`.
- Metrics (level %, cents): monospace, small, right-aligned.
- The wordmark is `LINOS` (titleLarge, w700, tracking 5) + `TUNER` in brass.

## Signature elements (tuner screen)

- **String rail** — six vertical bars with physically accurate tapering
  (5.0 → 1.8 px). Active bar glows brass; in-tune bar glows emerald; locked
  string shows an AUTO-owned ordinal badge.
- **Hero note** — giant note name + octave, caption `5TH STRING · A2`, and a
  status line `+2.3 ¢ · SHARP`, all color-coded by status. Pulses and halos on
  the in-tune moment.
- **Needle gauge** — custom painter, ±50 ¢ arc, ticks every 5 ¢ (major every
  10 ¢), a ±6 ¢ in-tune band, brass hub, animated needle.
- **Level meter** — 6 px bar with brass gradient fill, monospace percentage,
  and a sweet-spot marker at 65 % that turns emerald inside the 45–85 % zone.

## Motion

- State color changes: 160–220 ms.
- Needle and level sweeps: `easeOutCubic` (or `easeOut`) tween builders.
- Press micro-interactions: 90 ms scale/opacity via the `_PressScale` wrapper.
- In-tune reward: 350 ms pulse + glowing halo.
- Dialog entrance: 260 ms `easeOutBack` spring.
- Reduced motion is honored everywhere via `MediaQuery.disableAnimationsOf`
  (running animations are skipped or set to `Duration.zero`).

## Haptics

`Haptics` helper in `lib/ui/core/haptics/haptic_feedback.dart`:

| Moment                | Feedback                                   |
|-----------------------|--------------------------------------------|
| String auto-detected  | `HapticFeedback.lightImpact`               |
| Manual string select  | `HapticFeedback.selectionClick`            |
| String comes in tune  | `HapticFeedback.mediumImpact`              |

## Interaction patterns

- Interactive surfaces use `_PressScale` (scale + optional opacity on press)
  layered over `InkWell` ripples.
- Bottom sheets: `showModalBottomSheet` with `showDragHandle: true`, surface
  background, 24 px side padding, 32 px bottom padding.
- Every interactive element carries a `Semantics` label; decorative legends
  are wrapped in `ExcludeSemantics`; animated readouts use `AnimatedContainer`,
  `AnimatedDefaultTextStyle` and `AnimatedBuilder` so screen readers get a
  stable label.