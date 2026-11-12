import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import 'bridge_step.dart';
import 'done_step.dart';
import 'machine_step.dart';
import 'setup_controller.dart';
import 'setup_step_layout.dart';
import 'wifi_step.dart';

/// Einrichtung beim ersten Start: ein Schritt pro Bildschirm, klar geführt.
class EinrichtungPage extends ConsumerWidget {
  const EinrichtungPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(setupStepProvider);
    final steps = ref.read(setupStepProvider.notifier);
    // Zurück ist erlaubt bis zur WLAN-Wahl; danach ist die Brücke eingerichtet.
    final canGoBack = step.index > 0 && step.index <= SetupStep.wifi.index;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && canGoBack) steps.back();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: canGoBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: context.l10n.back,
                  onPressed: steps.back,
                )
              : null,
          title: Text(
            context.l10n.setupStepOf(step.index + 1, SetupStep.values.length),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: LinearProgressIndicator(
              value: (step.index + 1) / SetupStep.values.length,
              minHeight: 6,
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: ValueKey(step),
            child: switch (step) {
              SetupStep.welcome => const _WelcomeStep(),
              SetupStep.bridge => const BridgeStep(),
              SetupStep.wifi => const WifiStep(),
              SetupStep.machine => const MachineStep(),
              SetupStep.done => const DoneStep(),
            },
          ),
        ),
      ),
    );
  }
}

class _WelcomeStep extends ConsumerWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SetupStepLayout(
      visual: const SetupIcon(Icons.soup_kitchen_rounded),
      title: l10n.setupWelcomeTitle,
      text: l10n.setupWelcomeText,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: ref.read(setupStepProvider.notifier).next,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(64),
            ),
            child: Text(l10n.setupStart),
          ),
          const SizedBox(height: 12),
          // Brücke ist schon im Heim-WLAN (z. B. zweites Handy, Entwicklung): direkt
          // im WLAN suchen und koppeln (Bestätigung durch ein
          // schon gekoppeltes Handy), ohne Bluetooth-Einrichtung.
          OutlinedButton(
            onPressed: () {
              ref.read(setupDoneProvider.notifier).set(true);
              context.go('/mehr/verbindung');
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: Text(l10n.setupAlreadyInWifi),
          ),
        ],
      ),
    );
  }
}
