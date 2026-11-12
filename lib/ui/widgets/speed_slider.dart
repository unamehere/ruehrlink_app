import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../theme.dart';

/// Stufen-Schieberegler nach dem Vorbild des Drehknopfs an der Maschine:
/// rastet auf die benannten Stufen aus `caps.speeds` ein (Reihenfolge = Liste),
/// „Aus“ ist die Ruhestellung, die Füllung wächst von „Aus“ zur gewählten Stufe.
/// Gruppen (Intervall-Rühren, Dauerstufen) sind farblich abgesetzt und betitelt.
///
/// Bedienung: ziehen oder tippen (mit Rast-Vibration), feinfühlig über − und +.
/// Rein darstellend; Werte kommen vom Aufrufer.
class SpeedSlider extends StatelessWidget {
  const SpeedSlider({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<SpeedOption> options;

  /// Gerätewert der gewählten Stufe (unbekannt → wie „Aus“ behandelt).
  final int selected;
  final ValueChanged<int> onChanged;

  int get _index {
    final i = options.indexWhere((o) => o.v == selected);
    if (i >= 0) return i;
    final off = options.indexWhere((o) => o.group == SpeedGroup.off);
    return off >= 0 ? off : 0;
  }

  void _select(int i) {
    if (i < 0 || i >= options.length || i == _index) return;
    HapticFeedback.selectionClick();
    onChanged(options[i].v);
  }

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final index = _index;
    final current = options[index];
    final caption = current.group == SpeedGroup.off
        ? null
        : speedGroupTitle(context, current.group);
    // Vorlesetext einer Stufe, z. B. „Dauerstufen 3“ oder „Aus“.
    String describe(int i) => options[i].group == SpeedGroup.off
        ? options[i].label
        : '${speedGroupTitle(context, options[i].group)} ${options[i].label}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.speed_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: Tokens.s),
                Text(label, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: Tokens.s),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: index > 0 ? () => _select(index - 1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: l10n.dialDecrease(label),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(Tokens.bigButton),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          current.label,
                          style: theme.textTheme.displaySmall,
                        ),
                      ),
                      Text(
                        caption ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: index < options.length - 1
                      ? () => _select(index + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: l10n.dialIncrease(label),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(Tokens.bigButton),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.s),
            Semantics(
              slider: true,
              label: label,
              value: describe(index),
              increasedValue: index < options.length - 1
                  ? describe(index + 1)
                  : null,
              decreasedValue: index > 0 ? describe(index - 1) : null,
              onIncrease: index < options.length - 1
                  ? () => _select(index + 1)
                  : null,
              onDecrease: index > 0 ? () => _select(index - 1) : null,
              excludeSemantics: true,
              child: _Track(options: options, index: index, onSelect: _select),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lokalisierter Titel einer Stufen-Gruppe.
String speedGroupTitle(BuildContext context, SpeedGroup group) =>
    switch (group) {
      SpeedGroup.off => context.l10n.valueOff,
      SpeedGroup.stir => context.l10n.speedGroupStir,
      SpeedGroup.continuous => context.l10n.speedGroupContinuous,
      SpeedGroup.other => context.l10n.speedGroupOther,
    };

/// Zusammenhängende Abschnitte gleicher Gruppe (Start, Länge, Gruppe).
List<(int, int, SpeedGroup)> _runs(List<SpeedOption> options) {
  final runs = <(int, int, SpeedGroup)>[];
  for (var i = 0; i < options.length; i++) {
    final g = options[i].group;
    if (runs.isNotEmpty && runs.last.$3 == g) {
      final (start, len, _) = runs.removeLast();
      runs.add((start, len + 1, g));
    } else {
      runs.add((i, 1, g));
    }
  }
  return runs;
}

class _Track extends StatelessWidget {
  const _Track({
    required this.options,
    required this.index,
    required this.onSelect,
  });

  final List<SpeedOption> options;
  final int index;
  final ValueChanged<int> onSelect;

  static const _titleH = 28.0;
  static const _trackH = 16.0;
  static const _thumb = 40.0;
  static const _touchH = 64.0;
  static const _labelH = 32.0;

  /// Ab dieser Zellbreite stehen alle Stufen-Beschriftungen unter der Leiste,
  /// darunter nur die beiden Enden und „Aus“.
  static const _allLabelsFrom = 40.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final runs = _runs(options);
    final off = options.indexWhere((o) => o.group == SpeedGroup.off);
    final origin = off >= 0 ? off : 0;
    final (lo, hi) = index < origin ? (index, origin) : (origin, index);

    Color base(SpeedGroup g) => switch (g) {
      SpeedGroup.off => scheme.surfaceContainerHighest,
      SpeedGroup.stir => scheme.tertiaryContainer,
      _ => scheme.primaryContainer,
    };
    Color fill(SpeedGroup g) =>
        g == SpeedGroup.stir ? scheme.tertiary : scheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cell = w / options.length;
        final showAll = cell >= _allLabelsFrom;
        // Schmal (Handy hochkant): nur die beiden Enden und „Aus“ beschriften –
        // direkt neben „Aus“ wäre kein Platz (Rührstufe 1 | Aus | min).
        bool edge(int i) =>
            options[i].group == SpeedGroup.off ||
            i == 0 ||
            i == options.length - 1;
        // „Aus“ darf in die (unbeschrifteten) Nachbarzellen hineinragen.
        double labelW(int i) =>
            !showAll && options[i].group == SpeedGroup.off ? cell * 3 : cell;
        int at(double dx) => (dx / cell).floor().clamp(0, options.length - 1);
        final trackTop = _titleH + (_touchH - _trackH) / 2;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => onSelect(at(d.localPosition.dx)),
          onHorizontalDragUpdate: (d) => onSelect(at(d.localPosition.dx)),
          child: SizedBox(
            height: _titleH + _touchH + _labelH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Gruppentitel über ihrem Abschnitt.
                for (final (start, len, g) in runs)
                  if (g != SpeedGroup.off)
                    Positioned(
                      left: start * cell,
                      width: len * cell,
                      top: 0,
                      height: _titleH,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          speedGroupTitle(context, g),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                // Leiste: je Gruppe ein Abschnitt mit Lücke dazwischen.
                for (final (start, len, g) in runs)
                  Positioned(
                    left: start * cell + 2,
                    width: len * cell - 4,
                    top: trackTop,
                    height: _trackH,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_trackH / 2),
                      child: Row(
                        children: [
                          for (var i = start; i < start + len; i++)
                            Expanded(
                              child: ColoredBox(
                                color: i >= lo && i <= hi && i != origin
                                    ? fill(g)
                                    : base(g),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                // Rastpunkte.
                for (var i = 0; i < options.length; i++)
                  Positioned(
                    left: (i + 0.5) * cell - 3,
                    top: trackTop + _trackH / 2 - 3,
                    width: 6,
                    height: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                // Griff.
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 120),
                  left: (index + 0.5) * cell - _thumb / 2,
                  top: _titleH + (_touchH - _thumb) / 2,
                  width: _thumb,
                  height: _thumb,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: options[index].group == SpeedGroup.off
                          ? scheme.outline
                          : fill(options[index].group),
                      border: Border.all(color: scheme.surface, width: 4),
                      boxShadow: const [
                        BoxShadow(blurRadius: 4, color: Color(0x33000000)),
                      ],
                    ),
                  ),
                ),
                // Beschriftungen unter der Leiste.
                for (var i = 0; i < options.length; i++)
                  if (showAll || edge(i))
                    Positioned(
                      left: (i + 0.5) * cell - labelW(i) / 2,
                      width: labelW(i),
                      top: _titleH + _touchH,
                      height: _labelH,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          options[i].label,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: i == index
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: i == index
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
