import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../layout.dart';
import '../theme.dart';

/// Schlichter Platzhalter für Tabs, die noch folgen.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
    required this.text,
  });

  final String title;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AdaptivePage(
        primary: Column(
          children: [
            const SizedBox(height: Tokens.xl),
            Icon(icon, size: 96, color: theme.colorScheme.primary),
            const SizedBox(height: Tokens.l),
            Text(
              context.l10n.comingSoon,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Tokens.s),
            Text(
              text,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
