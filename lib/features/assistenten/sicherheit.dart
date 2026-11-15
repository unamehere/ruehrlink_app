import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/storage/app_storage.dart';
import '../../l10n/l10n.dart';
import '../../ui/theme.dart';
import 'assistent.dart';

/// Sicherheitshinweise: sinnvoller Standard, aber abschaltbar (Grundsatz im Backlog: „soll nicht nerven“).
/// Was die Maschine selbst erzwingt (Kopf-Verriegelung, 60-°C-Drosselung), fragt die App nicht zusätzlich ab.
enum SicherheitsHinweise { alle, kritische, aus }

final sicherheitsHinweiseProvider =
    NotifierProvider<SicherheitsHinweiseNotifier, SicherheitsHinweise>(
      SicherheitsHinweiseNotifier.new,
    );

class SicherheitsHinweiseNotifier extends Notifier<SicherheitsHinweise> {
  @override
  SicherheitsHinweise build() {
    final i = ref.read(appStorageProvider).safetyHints;
    return SicherheitsHinweise.values[i.clamp(
      0,
      SicherheitsHinweise.values.length - 1,
    )];
  }

  Future<void> setze(SicherheitsHinweise v) async {
    state = v;
    await ref.read(appStorageProvider).setSafetyHints(v.index);
  }
}

/// Soll [h] bei dieser Einstellung erscheinen? Tipps und Ablauf-Infos immer.
bool zeigeHinweis(Hinweis h, SicherheitsHinweise s) {
  if (!h.sicherheit) return true;
  return switch (s) {
    SicherheitsHinweise.alle => true,
    SicherheitsHinweise.kritische => h.kritisch,
    SicherheitsHinweise.aus => false,
  };
}

/// Auswahl für die Einstellungsseite „Hinweise beim Kochen“.
class SicherheitsHinweiseEinstellung extends ConsumerWidget {
  const SicherheitsHinweiseEinstellung({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final wert = ref.watch(sicherheitsHinweiseProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.safetyHintsTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: Tokens.s),
        SegmentedButton<SicherheitsHinweise>(
          segments: [
            ButtonSegment(
              value: SicherheitsHinweise.alle,
              label: Text(l10n.safetyHintsAll),
            ),
            ButtonSegment(
              value: SicherheitsHinweise.kritische,
              label: Text(l10n.safetyHintsCritical),
            ),
            ButtonSegment(
              value: SicherheitsHinweise.aus,
              label: Text(l10n.safetyHintsOff),
            ),
          ],
          selected: {wert},
          onSelectionChanged: (v) =>
              ref.read(sicherheitsHinweiseProvider.notifier).setze(v.first),
        ),
        const SizedBox(height: Tokens.s),
        Text(
          l10n.safetyHintsDetail,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
