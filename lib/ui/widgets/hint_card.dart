import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Hinweiskarte mit Symbol, Text und optionaler Erklärung.
/// [emphasized] hebt sie farbig hervor (z. B. „Jetzt am Knopf drehen“).
class HintCard extends StatelessWidget {
  const HintCard({
    super.key,
    required this.icon,
    required this.text,
    this.detail,
    this.emphasized = false,
  });

  final IconData icon;
  final String text;
  final String? detail;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = emphasized ? scheme.onTertiaryContainer : scheme.onSurface;
    return Card(
      color: emphasized ? scheme.tertiaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(Tokens.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 30),
            const SizedBox(width: Tokens.s + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: theme.textTheme.titleMedium?.copyWith(color: fg),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
