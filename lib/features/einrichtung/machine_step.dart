import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import '../../ui/widgets/hint_card.dart';
import 'maschine_koppeln_anleitung.dart';
import 'setup_controller.dart';
import 'setup_step_layout.dart';

/// Schritt 4: Maschine mit der Brücke koppeln. Die Nutzerin drückt an der
/// Maschine „Verbinden“, die App stößt `POST /machine/onboard` an und zeigt den
/// Fortschritt (WS `onboard`). Während der Kopplung ist die Brücke im Heim-WLAN
/// nicht erreichbar – die App fragt deshalb weiter `GET /info` ab, bis die
/// Maschine als verbunden gemeldet wird (der WebSocket verbindet sich selbst neu).
///
/// Auch für „Maschine neu koppeln“ (Mehr) – dort mit eigenem [onDone]/[onLater].
class MachineStep extends ConsumerStatefulWidget {
  const MachineStep({super.key, this.onDone, this.onLater});

  /// Nach erfolgreicher Kopplung. Standard: nächster Einrichtungsschritt.
  final VoidCallback? onDone;

  /// „Später“. Standard: nächster Einrichtungsschritt.
  final VoidCallback? onLater;

  /// Die Brücke gibt nach höchstens 3 min auf; etwas Reserve für den Rückweg.
  static const timeout = Duration(minutes: 3, seconds: 30);
  static const pollInterval = Duration(seconds: 3);

  @override
  ConsumerState<MachineStep> createState() => _MachineStepState();
}

enum _Phase { idle, starting, searching, sent, offline }

class _MachineStepState extends ConsumerState<MachineStep> {
  _Phase _phase = _Phase.idle;
  String? _error;
  StreamSubscription<BridgeEvent>? _events;

  bool get _busy => _phase != _Phase.idle;

  @override
  void dispose() {
    unawaited(_events?.cancel());
    super.dispose();
  }

  void _setPhase(_Phase phase) {
    if (mounted && _busy) setState(() => _phase = phase);
  }

  void _finish({String? error}) {
    unawaited(_events?.cancel());
    _events = null;
    if (!mounted || !_busy) return;
    setState(() {
      _phase = _Phase.idle;
      _error = error;
    });
    if (error == null) {
      ref.invalidate(bridgeInfoProvider);
      ref.invalidate(applianceStatusProvider);
      (widget.onDone ?? ref.read(setupStepProvider.notifier).next)();
    }
  }

  Future<void> _onboard() async {
    final l10n = context.l10n;
    final api = ref.read(bridgeApiProvider);
    setState(() {
      _phase = _Phase.starting;
      _error = null;
    });
    _events = api.events().listen((e) {
      if (e is! OnboardEvent) return;
      switch (e.state) {
        case OnboardState.searching:
          _setPhase(_Phase.searching);
        case OnboardState.sent:
          _setPhase(_Phase.sent);
        case OnboardState.done:
          _finish();
        case OnboardState.failed:
          _finish(error: l10n.setupMachineFailed);
        case OnboardState.unknown:
          break;
      }
    });

    try {
      await api.onboardMachine();
    } on BridgeException {
      _finish(error: l10n.bridgeUnreachableHint);
      return;
    }
    if (_phase == _Phase.starting) _setPhase(_Phase.searching);

    // Ergebnis über /info – auch wenn die WS-Meldungen verloren gehen.
    final attempts =
        MachineStep.timeout.inSeconds ~/ MachineStep.pollInterval.inSeconds;
    for (var i = 0; i < attempts; i++) {
      await Future<void>.delayed(MachineStep.pollInterval);
      if (!mounted || !_busy) return;
      try {
        final info = await api.info();
        if (info.appliance?.connected ?? false) return _finish();
        if (_phase == _Phase.offline) _setPhase(_Phase.sent);
      } on BridgeException {
        _setPhase(_Phase.offline); // erwartet, solange die Brücke koppelt
      }
    }
    _finish(error: l10n.setupMachineTimeout);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final progress = switch (_phase) {
      _Phase.idle => null,
      _Phase.starting => l10n.setupMachineWaiting,
      _Phase.searching => l10n.setupMachineSearching,
      _Phase.sent => l10n.setupMachineSent,
      _Phase.offline => l10n.setupMachineOffline,
    };
    return SetupStepLayout(
      visual: const MaschineKoppelnVorschau(),
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
          if (progress != null) SetupProgress(progress),
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
            busy: _busy,
            onPressed: _onboard,
          ),
          const SizedBox(height: Tokens.s),
          TextButton(
            onPressed: _busy
                ? null
                : (widget.onLater ?? ref.read(setupStepProvider.notifier).next),
            child: Text(l10n.setupLater),
          ),
        ],
      ),
    );
  }
}
