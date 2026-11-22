import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/models/models.dart';
import '../../core/update/firmware.dart';
import '../../l10n/l10n.dart';
import '../../ui/layout.dart';
import '../../ui/theme.dart';
import '../../version.dart';
import '../einrichtung/setup_controller.dart';

/// Mehr-Tab. Vorerst nur die Verbindung zur Brücke; folgt: Brücke (Firmware,
/// Update, Speicher), Home Assistant, Datensicherung, Hilfe.
class MehrPage extends ConsumerWidget {
  const MehrPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabMehr)),
      body: AdaptivePage(
        primary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.router_rounded, size: 32),
                title: Text(l10n.mehrConnection),
                trailing: const Icon(Icons.chevron_right_rounded, size: 32),
                onTap: () => context.go('/mehr/verbindung'),
              ),
            ),
            const SizedBox(height: Tokens.s),
            Card(
              child: ListTile(
                leading: Badge(
                  isLabelVisible:
                      ref.watch(bundledUpdateProvider) != null ||
                      ref.watch(bridgeInfoProvider).value?.compat ==
                          BridgeCompat.bridgeTooOld,
                  child: const Icon(Icons.system_update_rounded, size: 32),
                ),
                title: Text(l10n.updateTitle),
                subtitle: Text(
                  l10n.updateBridgeVersionShort(
                    ref.watch(bridgeInfoProvider).value?.fw ?? '–',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 32),
                onTap: () => context.go('/mehr/update'),
              ),
            ),
            const SizedBox(height: Tokens.s),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.notifications_active_outlined,
                  size: 32,
                ),
                title: Text(l10n.nudgeTitle),
                trailing: const Icon(Icons.chevron_right_rounded, size: 32),
                onTap: () => context.go('/mehr/hinweise'),
              ),
            ),
            const SizedBox(height: Tokens.s),
            Card(
              child: ListTile(
                leading: const Icon(Icons.bug_report_outlined, size: 32),
                title: Text(l10n.problemTitle),
                subtitle: Text(l10n.problemSubtitle),
                trailing: const Icon(Icons.chevron_right_rounded, size: 32),
                onTap: () => context.go('/mehr/problem'),
              ),
            ),
            const SizedBox(height: Tokens.s),
            Card(
              child: ListTile(
                leading: const Icon(Icons.restart_alt_rounded, size: 32),
                title: Text(l10n.mehrRestartSetup),
                onTap: () => ref.read(setupDoneProvider.notifier).set(false),
              ),
            ),
            const SizedBox(height: Tokens.s),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.delete_forever_rounded,
                  size: 32,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(l10n.mehrReset),
                onTap: () => _reset(context, ref),
              ),
            ),
            const SizedBox(height: Tokens.s),
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined, size: 32),
                title: Text(l10n.mehrLicenses),
                trailing: const Icon(Icons.chevron_right_rounded, size: 32),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Rührlink',
                  applicationVersion: appVersion,
                ),
              ),
            ),
            const SizedBox(height: Tokens.l),
            Text(
              'Rührlink App $appVersion',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Werksreset der Brücke – nach deutlicher Sicherheitsabfrage.
  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          size: 40,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(l10n.resetTitle),
        content: Text(l10n.resetText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.resetConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(bridgeApiProvider).reset();
    } on BridgeException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.resetFailed)));
      return;
    }
    // Brücke ist jetzt leer: Token vergessen, Einrichtung von vorn.
    await ref.read(bridgeTargetProvider.notifier).forget();
    await ref.read(setupDoneProvider.notifier).set(false);
  }
}
