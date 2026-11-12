import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../ui/layout.dart';
import '../../ui/theme.dart';
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
                leading: const Icon(Icons.restart_alt_rounded, size: 32),
                title: Text(l10n.mehrRestartSetup),
                onTap: () => ref.read(setupDoneProvider.notifier).set(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
