import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/theme.dart';
import '../maschine/machine_controller.dart';
import 'werte.dart';

/// B5: Temperatur-Richtwerte als Schnellwahl im manuellen Modus („Anbraten 180 °C“).
/// Setzt nur den Entwurf – gesendet wird wie immer mit „An Maschine senden“.
class TemperaturSchnellwahl extends ConsumerWidget {
  const TemperaturSchnellwahl({super.key, required this.caps});

  final ApplianceCaps caps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final s = caps.clamp(ref.watch(machineControllerProvider).settings);
    final werte = [
      for (final r in Richtwert.values)
        if (caps.clampTemperature(r.grad) == r.grad) r,
    ];
    if (werte.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: Tokens.s,
      runSpacing: Tokens.s,
      children: [
        for (final r in werte)
          ChoiceChip(
            label: Text(
              l10n.tempPresetLabel(richtwertName(l10n, r), r.grad),
              style: theme.textTheme.titleSmall,
            ),
            selected: s.temperature == r.grad,
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.s,
              vertical: Tokens.s,
            ),
            onSelected: (_) => ref
                .read(machineControllerProvider.notifier)
                .edit(waehleRichtwert(caps, s, r.grad)),
          ),
      ],
    );
  }
}

/// Temperatur setzen; bei heißem Inhalt eine zu schnelle Dauerstufe auf die erlaubte Höchststufe senken
/// (die Brücke würde sie sonst ablehnen).
MachineSettings waehleRichtwert(
  ApplianceCaps caps,
  MachineSettings s,
  int grad,
) {
  final t = caps.clampTemperature(grad);
  final heiss = caps.hotTemp != null && t >= caps.hotTemp!;
  final speed = heiss && caps.tooFastWhenHot(s.speed)
      ? caps.hotSpeedMax!
      : s.speed;
  return s.copyWith(temperature: t, speed: speed);
}

String richtwertName(AppLocalizations l10n, Richtwert r) => switch (r) {
  Richtwert.schmelzen => l10n.tempPresetMelt,
  Richtwert.pochieren => l10n.tempPresetPoach,
  Richtwert.sieden => l10n.tempPresetSimmer,
  Richtwert.kochen => l10n.tempPresetBoil,
  Richtwert.sautieren => l10n.tempPresetSaute,
  Richtwert.anbraten => l10n.tempPresetSear,
};
