import 'package:material_ui/material_ui.dart';

import '../core/models/models.dart';
import '../l10n/l10n.dart';

/// Anzeigename eines Werkzeugs.
String werkzeugName(AppLocalizations l10n, Werkzeug w) => switch (w) {
  Werkzeug.kHaken => l10n.toolKHaken,
  Werkzeug.flexi => l10n.toolFlexi,
  Werkzeug.schneebesen => l10n.toolSchneebesen,
  Werkzeug.knethaken => l10n.toolKnethaken,
  Werkzeug.kochRuehrelement => l10n.toolKochRuehrelement,
  Werkzeug.daempfeinsatz => l10n.toolDaempfeinsatz,
};

/// Platzhalter-Symbol, bis eigene Piktogramme im Rührlink-Stil da sind (Backlog B3) –
/// bewusst keine Herstellergrafiken.
IconData werkzeugIcon(Werkzeug w) => switch (w) {
  Werkzeug.schneebesen => Icons.blender_rounded,
  Werkzeug.daempfeinsatz => Icons.waves_rounded,
  _ => Icons.handyman_rounded,
};
