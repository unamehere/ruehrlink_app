import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../ui/hilfe_knopf.dart';
import '../hilfe/hilfe_themen.dart';
import '../../ui/illustrations.dart';
import '../../ui/theme.dart';
import 'assistent.dart';
import 'assistent_page.dart';
import 'katalog.dart';

/// Abschnitt „Assistenten“ auf dem Kochen-Tab: je Assistent eine große Kachel.
class AssistentenSection extends StatelessWidget {
  const AssistentenSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UeberschriftMitHilfe(
            l10n.asSectionTitle,
            hilfeProgramme,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: Tokens.s),
          Text(
            l10n.asSectionHint,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Tokens.m),
          LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth >= 560 ? 3 : 2;
              final width = (c.maxWidth - (columns - 1) * Tokens.m) / columns;
              return Wrap(
                spacing: Tokens.m,
                runSpacing: Tokens.m,
                children: [
                  for (final a in alleAssistenten)
                    SizedBox(width: width, child: _AssistentKachel(a)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AssistentKachel extends StatelessWidget {
  const _AssistentKachel(this.assistent);

  final Assistent assistent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AssistentPage(assistent: assistent),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Tokens.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Illustration(assistent.bild, size: 72),
              const SizedBox(height: Tokens.m),
              Text(
                assistent.titel(l10n),
                style: theme.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                assistent.untertitel(l10n),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
