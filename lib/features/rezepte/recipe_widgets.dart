import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/format.dart';
import '../../ui/illustrations.dart';
import '../../ui/widgets/speed_slider.dart';
import 'recipe_library.dart';

/// Foto eines Rezepts; ohne Foto (oder solange es lädt) eine Illustration passend zum Titel.
class RecipeImage extends ConsumerWidget {
  const RecipeImage({
    super.key,
    required this.recipe,
    this.aspectRatio = 4 / 3,
  });

  final Recipe recipe;
  final double aspectRatio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sha = recipe.photo;
    final bytes = sha == null
        ? null
        : ref.watch(recipePhotoProvider(sha)).value;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: bytes != null
          ? Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stack) =>
                  RecipeIllustration(title: recipe.title),
            )
          : RecipeIllustration(title: recipe.title),
    );
  }
}

/// Platzhalter-Bild: Illustration auf getöntem Grund (keine Herstellergrafiken).
class RecipeIllustration extends StatelessWidget {
  const RecipeIllustration({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: LayoutBuilder(
      builder: (context, c) => Center(
        child: Illustration(
          Illustrations.forName(title) ?? Illustrations.cooking,
          size: (c.biggest.shortestSide * 0.55).clamp(32, 160),
        ),
      ),
    ),
  );
}

/// Kurzbeschreibung eines Schritts für Listen: „Wiegen: 500 g“, „Maschine: Stufe 2 · 1:00“.
/// `null` bei reinen Textschritten.
String? stepSummary(
  BuildContext context,
  RecipeStep step, {
  required double factor,
  ApplianceCaps? caps,
  List<Program> programs = const [],
}) {
  final l10n = context.l10n;
  final w = step.weigh;
  if (w != null) {
    return l10n.recipeStepWeigh(
      '${formatAmount(w.target * factor)} ${w.unit}'.trim(),
    );
  }
  final m = step.machine;
  if (m == null) return null;
  final id = m.programId;
  if (id != null) {
    final p = programs.where((p) => p.id == id).firstOrNull;
    return l10n.recipeStepProgram(p?.name ?? id);
  }
  return l10n.recipeStepMachine(machineValues(context, m.settings!, caps));
}

/// „Stufe 2 · 1:00 · 100 °C“ bzw. „Ruhen · 10:00“.
String machineValues(
  BuildContext context,
  MachineSettings v,
  ApplianceCaps? caps,
) {
  final l10n = context.l10n;
  final time = formatDuration(v.time);
  if (caps?.speedOption(v.speed)?.group == SpeedGroup.off ||
      (caps == null && v.speed == 0)) {
    return v.temperature > 0
        ? '${l10n.programStepRest(time)} · ${l10n.temperatureValue(v.temperature)}'
        : l10n.programStepRest(time);
  }
  final speed = speedText(context, caps, v.speed);
  return v.temperature > 0
      ? l10n.programStepLineHeat(speed, time, v.temperature)
      : l10n.programStepLine(speed, time);
}
