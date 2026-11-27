import 'package:material_ui/material_ui.dart';

import '../core/models/models.dart';
import '../l10n/l10n.dart';
import 'icons/teile_icon.dart';

/// Anzeigename eines Werkzeugs.
String werkzeugName(AppLocalizations l10n, Werkzeug w) => switch (w) {
  Werkzeug.kHaken => l10n.toolKHaken,
  Werkzeug.flexi => l10n.toolFlexi,
  Werkzeug.schneebesen => l10n.toolSchneebesen,
  Werkzeug.knethaken => l10n.toolKnethaken,
  Werkzeug.kochRuehrelement => l10n.toolKochRuehrelement,
  Werkzeug.daempfeinsatz => l10n.toolDaempfeinsatz,
};

/// Piktogramm eines Werkzeugs (siehe `icons/teile_icon.dart`).
class WerkzeugBild extends StatelessWidget {
  const WerkzeugBild(
    this.werkzeug, {
    super.key,
    this.size = 40,
    this.color,
    this.background,
  });

  final Werkzeug werkzeug;
  final double size;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) => TeilBild(
    werkzeugTeil(werkzeug),
    size: size,
    color: color,
    background: background,
    semanticLabel: werkzeugName(context.l10n, werkzeug),
  );
}

/// Werkzeug, das vor [index] zuletzt im Einsatz war (oder `null`).
Werkzeug? werkzeugVor(List<RecipeStep> steps, int index) =>
    steps.take(index).map((s) => s.tool).whereType<Werkzeug>().lastOrNull;

/// Werkzeug, das in Schritt [index] drin ist: neu eingesetzt oder vom letzten Wechsel davor
/// (`null` = das Rezept sagt nichts dazu).
Werkzeug? werkzeugIn(List<RecipeStep> steps, int index) =>
    steps[index].tool ?? werkzeugVor(steps, index);

/// Kleines Kennzeichen an Maschinenschritten: Piktogramm und „mit K-Haken“. Ergänzt den
/// Werkzeugwechsel-Hinweis, damit man an jeder Maschinenfunktion sieht, was drin sein soll.
class WerkzeugMarke extends StatelessWidget {
  const WerkzeugMarke(this.werkzeug, {super.key, this.size = 24});

  final Werkzeug werkzeug;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Row(
      children: [
        WerkzeugBild(werkzeug, size: size),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            l10n.toolWith(werkzeugName(l10n, werkzeug)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
