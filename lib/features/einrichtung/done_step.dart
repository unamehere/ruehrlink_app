import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import '../../ui/widgets/hint_card.dart';
import 'setup_controller.dart';
import 'setup_step_layout.dart';

/// Schritt 5: Fertig – mit Probelauf (30 s, Stufe 1, ohne Heizen).
class DoneStep extends ConsumerStatefulWidget {
  const DoneStep({super.key});

  /// Probelauf laut docs/screens.md: 30 s ohne Heizen auf der Dauerstufe „1“
  /// (falls das Gerät keine hat: die erste Dauerstufe). Grenzen aus den caps.
  static MachineSettings trialFor(ApplianceCaps caps) {
    final continuous = caps.speedsIn(SpeedGroup.continuous);
    final speed =
        continuous.where((o) => o.label == '1').firstOrNull ??
        continuous.firstOrNull;
    return caps.clamp(
      MachineSettings(temperature: 0, time: 30, speed: speed?.v ?? 0),
    );
  }

  @override
  ConsumerState<DoneStep> createState() => _DoneStepState();
}

class _DoneStepState extends ConsumerState<DoneStep> {
  bool _busy = false;
  String? _result;
  bool _ok = false;

  Future<void> _trial(ApplianceCaps caps) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(bridgeApiProvider).sendProgram(DoneStep.trialFor(caps));
      _ok = true;
      _result = l10n.setupTrySent;
    } on BridgeException {
      _ok = false;
      _result = l10n.sendFailed;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final caps = ref.watch(bridgeInfoProvider).value?.readyCaps;
    return SetupStepLayout(
      visual: const SetupIcon(Icons.check_rounded),
      title: l10n.setupDoneTitle,
      text: l10n.setupDoneText,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ref.read(setupStepProvider.notifier).machineAlreadyPaired) ...[
            HintCard(
              icon: Icons.link_rounded,
              text: l10n.setupMachineAlreadyPaired,
            ),
            const SizedBox(height: Tokens.m),
          ],
          BigButton(
            label: l10n.setupTrySend,
            icon: Icons.play_circle_outline_rounded,
            kind: BigButtonKind.secondary,
            busy: _busy,
            onPressed: caps == null ? null : () => _trial(caps),
          ),
          if (_result != null) ...[
            const SizedBox(height: Tokens.m),
            _ok
                ? HintCard(
                    icon: Icons.touch_app_rounded,
                    text: _result!,
                    emphasized: true,
                  )
                : SetupError(_result!),
          ],
        ],
      ),
      action: BigButton(
        label: l10n.setupFinish,
        icon: Icons.arrow_forward_rounded,
        onPressed: () => ref.read(setupDoneProvider.notifier).set(true),
      ),
    );
  }
}
