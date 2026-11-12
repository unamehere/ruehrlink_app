import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../theme.dart';

/// Großer Regler für einen Maschinenwert: Beschriftung, großer Wert, − und +.
///
/// Rein darstellend – welche Werte erlaubt sind und in welchen Schritten,
/// entscheidet der Aufrufer (aus den `caps` des Geräts). Ein `null`-Callback
/// sperrt die jeweilige Taste (Grenze erreicht). Optional ein Schieberegler.
class ValueDial extends StatelessWidget {
  const ValueDial({
    super.key,
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    this.icon,
    this.slider,
  });

  final String label;

  /// Fertig formatierter Wert, z. B. „120 °C“ oder „4:30“.
  final String value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final IconData? icon;
  final DialSlider? slider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: Tokens.s),
                ],
                Text(label, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: Tokens.s),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: onDecrement,
                  icon: const Icon(Icons.remove_rounded),
                  tooltip: l10n.dialDecrease(label),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(Tokens.bigButton),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    label: label,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(value, style: theme.textTheme.displaySmall),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onIncrement,
                  icon: const Icon(Icons.add_rounded),
                  tooltip: l10n.dialIncrease(label),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(Tokens.bigButton),
                  ),
                ),
              ],
            ),
            if (slider case final s?)
              Slider(
                value: s.value.clamp(s.min, s.max),
                min: s.min,
                max: s.max,
                divisions: s.divisions,
                label: value,
                onChanged: s.onChanged,
              ),
          ],
        ),
      ),
    );
  }
}

/// Konfiguration des optionalen Schiebereglers unter einem [ValueDial].
class DialSlider {
  const DialSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
}
