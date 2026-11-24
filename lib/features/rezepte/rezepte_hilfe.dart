import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../ui/theme.dart';

/// Kleiner „?“-Knopf für die App-Leiste: öffnet [showRezepteHilfe].
class RezepteHilfeButton extends StatelessWidget {
  const RezepteHilfeButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.recipesHelp,
    icon: const Icon(Icons.help_outline_rounded),
    onPressed: () => showRezepteHilfe(context),
  );
}

/// Kurze Hilfe zu Rezepten als Fenster von unten – nur auf Wunsch, nie von selbst.
Future<void> showRezepteHilfe(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _Hilfe(),
    );

class _Hilfe extends StatelessWidget {
  const _Hilfe();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final items = [
      (Icons.wifi_tethering_rounded, l10n.helpWhereTitle, l10n.helpWhereText),
      (
        Icons.format_list_bulleted_rounded,
        l10n.helpIngredientsTitle,
        l10n.helpIngredientsText,
      ),
      (Icons.swap_horiz_rounded, l10n.helpToolTitle, l10n.helpToolText),
      (Icons.blender_rounded, l10n.helpMachineTitle, l10n.helpMachineText),
      (Icons.scale_rounded, l10n.helpWeighTitle, l10n.helpWeighText),
      (
        Icons.people_alt_outlined,
        l10n.helpServingsTitle,
        l10n.helpServingsText,
      ),
    ];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Tokens.l, 0, Tokens.l, Tokens.l),
          children: [
            Text(l10n.helpTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: Tokens.m),
            for (final (icon, title, text) in items)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.m),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: theme.colorScheme.primary),
                    const SizedBox(width: Tokens.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(text, style: theme.textTheme.bodyMedium),
                        ],
                      ),
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
