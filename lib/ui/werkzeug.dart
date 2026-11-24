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
