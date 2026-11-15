import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/theme.dart';
import '../waage/scale_view.dart';
import 'recipe_library.dart';

/// Waage im Kochmodus (Wiegeschritt).
///
/// Schnittstelle, die der Kochmodus (`kochmodus_page.dart`, `_StepPage`) benutzt:
///  - [target]: Zielmenge dieses Schritts, **schon mit den Portionen skaliert**
///    (`target.target` in `target.unit`, meist „g“).
///  - [label]: Text des Schritts (z. B. „Mehl in die Schüssel wiegen.“), nur zur Anzeige.
///  - [onReached]: wird aufgerufen, sobald das Ziel erreicht ist. Der Kochmodus hebt dann
///    „Weiter“ hervor (er blättert nicht selbst weiter).
///  - Der Kochmodus legt pro Schritt eine neue Instanz an (Key = Schrittnummer): Beim Betreten
///    des Schritts setzt die Waage einmal Tara, damit jede Zutat für sich gewogen wird.
///
/// Gramm und Kilogramm laufen über die Waage; andere Einheiten (ml, EL …) zeigen nur die Menge.
class WeighStepSlot extends StatelessWidget {
  const WeighStepSlot({
    super.key,
    required this.target,
    this.label,
    this.onReached,
  });

  final WeighTarget target;
  final String? label;
  final VoidCallback? onReached;

  /// Zielmenge in Gramm, oder `null`, wenn die Waage die Einheit nicht messen kann.
  static double? grams(WeighTarget t) => switch (t.unit.trim().toLowerCase()) {
    'g' || '' => t.target,
    'kg' => t.target * 1000,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final amount = '${formatAmount(target.target)} ${target.unit}'.trim();
    final g = grams(target);
    if (g != null && g > 0) {
      return ScaleView(
        target: g,
        ingredient: context.l10n.cookWeighTarget(amount),
        size: 220,
        autoTare: true,
        onReached: onReached,
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radius),
        border: Border.all(color: scheme.outline, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.l),
        child: Column(
          children: [
            Icon(Icons.straighten_rounded, size: 64, color: scheme.primary),
            const SizedBox(height: Tokens.m),
            Text(
              context.l10n.cookWeighTarget(amount),
              style: theme.textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Tokens.s),
            Text(
              context.l10n.cookWeighPlaceholder,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
