import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../waage/scale_view.dart';
import 'recipe_library.dart';

/// Waage für eine Zutat im Kochmodus.
///
///  - [ingredient]: schon mit den Portionen skaliert; g/kg oder ml/l (`ingredient.grams`).
///  - [onReached]: einmal, sobald die Zielmenge erreicht ist.
///  - Pro Zutat eine neue Instanz (Key): Beim ersten Messwert setzt die Waage einmal Tara, damit
///    jede Zutat für sich gewogen wird.
class WeighStepSlot extends StatelessWidget {
  const WeighStepSlot({
    super.key,
    required this.ingredient,
    this.onReached,
    this.onSettled,
  });

  final Ingredient ingredient;
  final VoidCallback? onReached;

  /// Gewicht liegt [scaleSettleTime] ruhig im Zielbereich (siehe [ScaleView.onSettled]).
  final VoidCallback? onSettled;

  @override
  Widget build(BuildContext context) => ScaleView(
    target: ingredient.grams,
    ingredient: context.l10n.cookWeighTarget(weighText(ingredient)),
    size: 220,
    autoTare: true,
    onReached: onReached,
    onSettled: onSettled,
  );
}
