import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/theme.dart';
import 'recipe_library.dart';

/// ===========================================================================
/// PLATZHALTER – Waage im Kochmodus (Wiegeschritt)
/// ===========================================================================
///
/// Hier wird das Waage-Widget (Ring, der sich bis zum Ziel füllt, Tara-Button) eingehängt,
/// das parallel entsteht. Bis dahin zeigt der Platzhalter nur die Zielmenge als Text.
/// Eigene Waage-Logik gehört NICHT hierher.
///
/// Schnittstelle, die der Kochmodus (`kochmodus_page.dart`, `_StepPage`) benutzt:
///  - [target]: Zielmenge dieses Schritts, **schon mit den Portionen skaliert**
///    (`target.target` in `target.unit`, meist „g“).
///  - [label]: Text des Schritts (z. B. „Mehl in die Schüssel wiegen.“), nur zur Anzeige.
///  - [onReached]: optional; das Waage-Widget ruft es auf, sobald das Ziel erreicht ist.
///    Der Kochmodus hebt dann „Weiter“ hervor (er blättert nicht selbst weiter).
///  - Der Kochmodus legt pro Schritt eine neue Instanz an (Key = Schrittnummer), d. h. Tara
///    und Zustand dürfen im State des Widgets leben.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final amount = '${formatAmount(target.target)} ${target.unit}'.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radius),
        border: Border.all(color: scheme.outline, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.l),
        child: Column(
          children: [
            Icon(Icons.scale_rounded, size: 64, color: scheme.primary),
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
