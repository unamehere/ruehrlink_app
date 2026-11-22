import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/theme.dart';

/// Speicher des Rührlink (`storage` aus `GET /info`): Art, Belegung, schmaler Füllbalken.
/// Unaufdringlich – nur in Mehr → Verbindung. Ab [almostFull] ein dezenter Hinweis.
class StorageRow extends StatelessWidget {
  const StorageRow(this.storage, {super.key});

  final StorageInfo storage;

  /// Ab diesem Anteil belegt gilt der Speicher als fast voll.
  static const almostFull = 0.9;

  /// Anteil belegt (0…1), ohne Gesamtgröße 0.
  static double usedFraction(StorageInfo s) => s.totalKB <= 0
      ? 0
      : ((s.totalKB - s.freeKB) / s.totalKB).clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final mb = NumberFormat.decimalPattern('de');
    final usedKB = (storage.totalKB - storage.freeKB).clamp(0, storage.totalKB);
    final fraction = usedFraction(storage);
    final full = fraction >= almostFull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  storage.backend == 'sd'
                      ? Icons.sd_card_outlined
                      : Icons.memory_rounded,
                  size: 32,
                ),
                const SizedBox(width: Tokens.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.storageTitle} · '
                        '${storage.backend == 'sd' ? l10n.storageKindSd : l10n.storageKindFlash}',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        l10n.storageUsed(
                          mb.format((usedKB / 1024).round()),
                          mb.format((storage.totalKB / 1024).round()),
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.s),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(value: fraction, minHeight: 4),
            ),
            if (full) ...[
              const SizedBox(height: Tokens.s),
              Text(
                l10n.storageAlmostFull,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
