import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_providers.dart';
import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/format.dart';
import '../../ui/input.dart';
import '../../ui/layout.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import '../../ui/widgets/hint_card.dart';
import '../../ui/widgets/speed_slider.dart';
import '../../ui/widgets/value_dial.dart';
import 'live_status_band.dart';
import 'machine_controller.dart';
import 'regler.dart';

/// Manuelle Steuerung: Live-Status, drei Regler aus `caps`, Senden, Stopp.
///
/// Breit (Tablet quer): Status, Senden und Stopp links, Regler rechts.
/// Schmal: alles untereinander, Senden und Stopp nebeneinander unten fest.
class MaschinePage extends ConsumerWidget {
  const MaschinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final twoPane = WindowSize.of(context).twoPane;
    final stop = BigButton.stop(
      label: l10n.stop,
      onPressed: () => _stop(context, ref),
    );
    // Die beiden wichtigsten Knöpfe nebeneinander – ohne Scrollen erreichbar.
    final actions = Row(
      children: [
        const Expanded(child: _SendButton()),
        const SizedBox(width: Tokens.m),
        Expanded(child: stop),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.machineTitle)),
      body: AdaptivePage(
        primary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ref.watch(bridgeTargetProvider) is DemoTarget) ...[
              HintCard(icon: Icons.science_outlined, text: l10n.demoBanner),
              const SizedBox(height: Tokens.m),
            ],
            const LiveStatusBand(),
            const _BowlHint(),
            if (twoPane) ...[const SizedBox(height: Tokens.l), actions],
          ],
        ),
        secondary: const _Controls(),
        bottom: twoPane ? null : actions,
      ),
    );
  }

  Future<void> _stop(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(machineControllerProvider.notifier).stop();
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? l10n.stopDone : l10n.stopFailed)),
    );
  }
}

/// Regler + Senden – oder ein klarer Hinweis, warum gerade nicht.
class _Controls extends ConsumerWidget {
  const _Controls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final info = ref.watch(bridgeInfoProvider);
    final caps = info.value?.readyCaps;

    if (caps == null) {
      if (info.isLoading && !info.hasValue) {
        return const Center(child: CircularProgressIndicator());
      }
      final unreachable = info.hasError;
      return _Notice(
        title: unreachable ? l10n.bridgeUnreachable : l10n.machineNotConnected,
        text: unreachable
            ? l10n.bridgeUnreachableHint
            : l10n.machineNotConnectedHint,
        onRetry: () {
          ref.invalidate(bridgeInfoProvider);
          ref.invalidate(applianceStatusProvider);
        },
      );
    }

    final draft = ref.watch(machineControllerProvider);
    final controller = ref.read(machineControllerProvider.notifier);
    final s = caps.clamp(draft.settings);
    final invalid = ref.read(invalidInputsProvider.notifier);
    void edit(MachineSettings next) => controller.edit(next);
    VoidCallback? step(int? next, MachineSettings Function(int) apply) =>
        next == null ? null : () => edit(apply(next));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueDial(
          label: l10n.dialTemperature,
          icon: Icons.thermostat_rounded,
          value: s.temperature == 0
              ? l10n.valueOff
              : l10n.temperatureValue(s.temperature),
          onDecrement: step(
            Regler.temperature(caps, s.temperature, up: false),
            (v) => s.copyWith(temperature: v),
          ),
          onIncrement: step(
            Regler.temperature(caps, s.temperature, up: true),
            (v) => s.copyWith(temperature: v),
          ),
          editor: ValueEditor(
            text: s.temperature == 0 ? '' : '${s.temperature}',
            hint: l10n.valueOff,
            suffix: '°C',
            maxLength: 3,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            validate: (t) => Regler.parseTemperature(caps, t) == null
                ? l10n.inputTempInvalid(caps.tempMin, caps.tempMax)
                : null,
            onSubmit: (t) =>
                edit(s.copyWith(temperature: Regler.parseTemperature(caps, t))),
            onValidityChanged: (ok) => invalid.report('temp', valid: ok),
          ),
        ),
        const SizedBox(height: Tokens.m),
        ValueDial(
          label: l10n.dialTime,
          icon: Icons.timer_outlined,
          value: formatDuration(s.time),
          onDecrement: step(
            Regler.time(caps, s.time, up: false),
            (v) => s.copyWith(time: v),
          ),
          onIncrement: step(
            Regler.time(caps, s.time, up: true),
            (v) => s.copyWith(time: v),
          ),
          editor: ValueEditor(
            text: formatDuration(s.time),
            formatters: [DurationDigitsFormatter()],
            validate: (t) => Regler.parseTime(caps, t) == null
                ? l10n.inputTimeInvalid(formatDuration(caps.timeMaxS))
                : null,
            onSubmit: (t) => edit(s.copyWith(time: Regler.parseTime(caps, t))),
            onValidityChanged: (ok) => invalid.report('time', valid: ok),
          ),
        ),
        const SizedBox(height: Tokens.m),
        SpeedSlider(
          label: l10n.dialSpeed,
          options: caps.speeds,
          selected: s.speed,
          onChanged: (v) => edit(s.copyWith(speed: v)),
        ),
        const SizedBox(height: Tokens.l),
        _SendFeedback(draft.sendState),
        if (!caps.remoteStart)
          HintCard(
            icon: Icons.touch_app_rounded,
            text: l10n.startAtKnob,
            detail: l10n.startAtKnobHint,
            emphasized: draft.sendState == SendState.confirmed,
          ),
      ],
    );
  }
}

/// „Senden“ – unten neben Stopp. Gesperrt ohne Gerät oder solange ein Feld ungültig ist.
class _SendButton extends ConsumerWidget {
  const _SendButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final caps = ref.watch(bridgeInfoProvider).value?.readyCaps;
    final draft = ref.watch(machineControllerProvider);
    final hasInvalid = ref.watch(invalidInputsProvider).isNotEmpty;
    final sending = draft.sendState == SendState.sending;
    return BigButton(
      label: sending ? l10n.sending : l10n.sendToMachine,
      icon: Icons.send_rounded,
      busy: sending,
      // Vor dem Senden die laufende Eingabe schließen, damit ein gültiger getippter Wert übernommen wird.
      onPressed: caps == null || hasInvalid
          ? null
          : () async {
              FocusManager.instance.primaryFocus?.unfocus();
              await Future<void>.delayed(Duration.zero);
              if (ref.read(invalidInputsProvider).isEmpty) {
                await ref.read(machineControllerProvider.notifier).send();
              }
            },
    );
  }
}

class _SendFeedback extends StatelessWidget {
  const _SendFeedback(this.state);

  final SendState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, String text, Color color)? feedback = switch (state) {
      SendState.confirmed => (
        Icons.check_circle_rounded,
        l10n.sendConfirmed,
        scheme.primary,
      ),
      SendState.unconfirmed => (
        Icons.hourglass_bottom_rounded,
        l10n.sendUnconfirmed,
        scheme.onSurfaceVariant,
      ),
      SendState.failed => (Icons.error_rounded, l10n.sendFailed, scheme.error),
      _ => null,
    };
    if (feedback == null) return const SizedBox.shrink();
    final (icon, text, color) = feedback;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.m),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: Tokens.s + 4),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// „Schüssel einsetzen und Kopf schließen“, wenn die Maschine es meldet.
class _BowlHint extends ConsumerWidget {
  const _BowlHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(applianceStatusProvider).value;
    if (status == null || !status.connected || status.readyToStart) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.m),
      child: HintCard(
        icon: Icons.warning_amber_rounded,
        text: context.l10n.checkBowl,
        emphasized: true,
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.title,
    required this.text,
    required this.onRetry,
  });

  final String title;
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: Tokens.s),
            Text(text, style: theme.textTheme.bodyLarge),
            const SizedBox(height: Tokens.l),
            BigButton(
              label: context.l10n.retry,
              icon: Icons.refresh_rounded,
              kind: BigButtonKind.secondary,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
