import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../l10n/l10n.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import '../../ui/widgets/hint_card.dart';
import 'setup_controller.dart';
import 'setup_step_layout.dart';

/// Schritt 4: Maschine mit der Brücke koppeln. Die Nutzerin drückt an der
/// Maschine „Verbinden“, die App stößt `POST /machine/onboard` an und wartet,
/// bis die Brücke das Gerät als verbunden meldet.
class MachineStep extends ConsumerStatefulWidget {
  const MachineStep({super.key});

  static const timeout = Duration(minutes: 2);
  static const pollInterval = Duration(seconds: 2);

  @override
  ConsumerState<MachineStep> createState() => _MachineStepState();
}

class _MachineStepState extends ConsumerState<MachineStep> {
  bool _waiting = false;
  String? _error;

  Future<void> _onboard() async {
    final l10n = context.l10n;
    final api = ref.read(bridgeApiProvider);
    setState(() {
      _waiting = true;
      _error = null;
    });
    final deadline = DateTime.now().add(MachineStep.timeout);
    try {
      await api.onboardMachine();
      while (mounted && DateTime.now().isBefore(deadline)) {
        final info = await api.info();
        if (info.appliance?.connected ?? false) {
          ref.invalidate(bridgeInfoProvider);
          ref.read(setupStepProvider.notifier).next();
          return;
        }
        await Future<void>.delayed(MachineStep.pollInterval);
      }
      if (mounted) setState(() => _error = l10n.setupMachineTimeout);
    } on BridgeException {
      if (mounted) setState(() => _error = l10n.bridgeUnreachableHint);
    } finally {
      if (mounted) setState(() => _waiting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SetupStepLayout(
      visual: const _ImagePlaceholder(),
      title: l10n.setupMachineTitle,
      text: l10n.setupMachineText,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HintCard(
            icon: Icons.settings_rounded,
            text: l10n.setupMachineInstruction,
            emphasized: true,
          ),
          if (_waiting) SetupProgress(l10n.setupMachineWaiting),
          if (_error != null) ...[
            const SizedBox(height: Tokens.m),
            SetupError(_error!),
          ],
        ],
      ),
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BigButton(
            label: l10n.setupMachineDone,
            icon: Icons.check_rounded,
            busy: _waiting,
            onPressed: _onboard,
          ),
          const SizedBox(height: Tokens.s),
          TextButton(
            onPressed: _waiting
                ? null
                : ref.read(setupStepProvider.notifier).next,
            child: Text(l10n.setupLater),
          ),
        ],
      ),
    );
  }
}

/// Platzhalter, bis die Bildanleitung (eigene Fotos, kein Herstellermaterial) da ist.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Tokens.radius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: Tokens.s),
            Text(
              context.l10n.setupMachineImage,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
