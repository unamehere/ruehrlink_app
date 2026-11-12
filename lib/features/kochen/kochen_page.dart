import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../ui/widgets/placeholder_page.dart';

/// Start-Tab. Folgt: Statusband, „Weiterkochen“, Lieblingsrezepte, Multi-Programme.
class KochenPage extends StatelessWidget {
  const KochenPage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderPage(
    title: context.l10n.tabKochen,
    icon: Icons.restaurant_rounded,
    text: context.l10n.kochenPlaceholder,
  );
}
