import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../l10n/l10n.dart';
import '../einrichtung/machine_step.dart';

/// „Maschine neu koppeln“ ohne Werksreset (Fähigkeit `machine.repair`, F18).
///
/// [confirmRepairMachine] fragt nach und lässt den Rührlink die Kopplung vergessen;
/// danach führt diese Seite mit demselben Schritt wie die Einrichtung durch die Kopplung.
class MaschineKoppelnPage extends StatelessWidget {
  const MaschineKoppelnPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.repairMachineTile)),
      body: MachineStep(
        onDone: () {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.repairMachineDone)));
          context.go('/mehr');
        },
        onLater: () => context.go('/mehr'),
      ),
    );
  }
}

/// Bestätigen, dann `POST /machine/repair`; bei Erfolg zur Kopplungsanleitung.
Future<void> confirmRepairMachine(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.link_off_rounded, size: 40),
      title: Text(l10n.repairMachineTitle),
      content: Text(l10n.repairMachineText),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.repairMachineConfirm),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.read(bridgeApiProvider).repairMachine();
  } on BridgeException catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e.code == 'busy' ? l10n.repairMachineBusy : l10n.repairMachineFailed,
        ),
      ),
    );
    return;
  }
  ref.invalidate(bridgeInfoProvider);
  ref.invalidate(applianceStatusProvider);
  router.go('/mehr/maschine-koppeln');
}
