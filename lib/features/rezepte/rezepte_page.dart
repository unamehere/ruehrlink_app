import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../ui/widgets/placeholder_page.dart';

/// Rezepte-Tab. Folgt: Raster mit Fotos, Suche, Rezeptseite (breit: Liste + Detail).
class RezeptePage extends StatelessWidget {
  const RezeptePage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderPage(
    title: context.l10n.tabRezepte,
    icon: Icons.menu_book_rounded,
    text: context.l10n.rezeptePlaceholder,
  );
}
