import 'package:material_ui/material_ui.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// Kurzzugriff auf die Texte: `context.l10n.tabKochen`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
