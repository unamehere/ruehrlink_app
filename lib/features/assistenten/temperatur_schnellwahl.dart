import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/theme.dart';
import '../maschine/machine_controller.dart';
import 'werte.dart';

/// B5 / F19: Temperatur-Richtwerte („Anbraten 180 °C“) als kleiner Knopf im Temperatur-Regler,
/// der ein Menü öffnet. Setzt nur den Entwurf – gesendet wird wie immer mit „An Maschine senden“.
class TemperaturVorschlaege extends ConsumerWidget {
  const TemperaturVorschlaege({super.key, required this.caps});

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
    return PopupMenuButton<int>(
      tooltip: l10n.tempPresetsTooltip,
      position: PopupMenuPosition.under,
      onSelected: (grad) => ref
          .read(machineControllerProvider.notifier)
          .edit(waehleRichtwert(caps, s, grad)),
      itemBuilder: (context) => [
        for (final r in werte)
          CheckedPopupMenuItem<int>(
            value: r.grad,
            checked: s.temperature == r.grad,
            child: Text(l10n.tempPresetLabel(richtwertName(l10n, r), r.grad)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.s,
          vertical: Tokens.s / 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              l10n.tempPresets,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
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
