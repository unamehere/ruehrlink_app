import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/illustrations.dart';
import '../../ui/layout.dart';
import '../../ui/theme.dart';
import '../../ui/werkzeug.dart';
import '../../ui/widgets/big_button.dart';
import '../kochen/programs.dart';
import 'recipe_library.dart';
import 'recipe_widgets.dart';

/// Rezeptseite: Foto, Portionen −/+, Zutaten (skaliert), Schritte, „Jetzt kochen“.
/// Breit (Tablet quer): Zutaten links, Schritte rechts.
class RecipePage extends ConsumerStatefulWidget {
  const RecipePage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends ConsumerState<RecipePage> {
  int? _servings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final recipe = ref.watch(recipeProvider(widget.id));
    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(l10n.recipeNotFound, style: theme.textTheme.bodyLarge),
        ),
      );
    }
    final base = recipe.servings < 1 ? 1 : recipe.servings;
    final servings = _servings ?? base;
    final factor = servings / base;
    final caps = ref.watch(bridgeInfoProvider).value?.readyCaps;
    final programs = ref.watch(bridgeProgramsProvider).value ?? const [];

    final primary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Tokens.radius),
          child: RecipeImage(recipe: recipe, aspectRatio: 16 / 10),
        ),
        const SizedBox(height: Tokens.m),
        Text(recipe.title, style: theme.textTheme.headlineMedium),
        if (recipe.tags.isNotEmpty) ...[
          const SizedBox(height: Tokens.s),
          Wrap(
            spacing: Tokens.s,
            runSpacing: Tokens.s,
            children: [
              for (final t in recipe.tags)
                Chip(label: Text(t), labelStyle: theme.textTheme.labelMedium),
            ],
          ),
        ],
        const SizedBox(height: Tokens.l),
        _ServingsStepper(
          servings: servings,
          onChanged: (v) => setState(() => _servings = v),
        ),
        const SizedBox(height: Tokens.l),
        Text(l10n.recipeIngredients, style: theme.textTheme.headlineSmall),
        const SizedBox(height: Tokens.s),
        for (final i in recipe.ingredients)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Illustration(
                  Illustrations.forName(i.name) ?? Illustrations.bowl,
                  size: 40,
                ),
                const SizedBox(width: Tokens.m),
                Expanded(
                  child: Text(
                    ingredientText(i, factor),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    final secondary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.recipeSteps, style: theme.textTheme.headlineSmall),
        const SizedBox(height: Tokens.s),
        for (final (n, s) in recipe.steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.m),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Text('${n + 1}', style: theme.textTheme.labelMedium),
                ),
                const SizedBox(width: Tokens.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (s.tool case final t?)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                werkzeugIcon(t),
                                size: 22,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: Tokens.s),
                              Expanded(
                                child: Text(
                                  l10n.toolInsert(werkzeugName(l10n, t)),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(s.text, style: theme.textTheme.bodyLarge),
                      if (s.ingredients.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            [
                              for (final i in s.ingredients)
                                ingredientText(i, factor),
                            ].join(' · '),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (stepSummary(
                            context,
                            s,
                            factor: factor,
                            caps: caps,
                            programs: programs,
                          )
                          case final summary?)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.blender_rounded,
                                size: 22,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: Tokens.s),
                              Expanded(
                                child: Text(
                                  summary,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: l10n.recipeEdit,
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.go('/rezepte/${recipe.id}/bearbeiten'),
          ),
          IconButton(
            tooltip: l10n.recipeDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _delete(recipe),
          ),
        ],
      ),
      body: AdaptivePage(
        primary: primary,
        secondary: secondary,
        bottom: recipe.steps.isEmpty
            ? null
            : BigButton(
                label: l10n.recipeCook,
                icon: Icons.play_arrow_rounded,
                onPressed: () => context.go(
                  '/rezepte/${recipe.id}/kochen?portionen=$servings',
                ),
              ),
      ),
    );
  }

  Future<void> _delete(Recipe recipe) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final ok = await _confirm(
      l10n.recipeDeleteTitle,
      l10n.recipeDeleteText(recipe.title),
      l10n.recipeDelete,
    );
    if (ok != true) return;
    final library = ref.read(recipeLibraryProvider.notifier);
    try {
      var result = await library.delete(recipe);
      if (result is RecipeConflict && !result.deleted) {
        if (!mounted) return;
        final again = await _confirm(
          l10n.conflictTitle,
          l10n.conflictDeleteText,
          l10n.conflictDeleteConfirm,
        );
        if (again != true) return;
        result = await library.delete(recipe.copyWith(rev: result.currentRev));
      }
      if (result is RecipeWritten || (result as RecipeConflict).deleted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.recipeDeleted)));
        router.go('/rezepte');
      }
    } on BridgeException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.bridgeUnreachable)));
    }
  }

  Future<bool?> _confirm(String title, String text, String action) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
          ],
        ),
      );
}

/// Große −/+ Knöpfe für die Portionen (auch mit nassen Händen gut zu treffen).
class _ServingsStepper extends StatelessWidget {
  const _ServingsStepper({required this.servings, required this.onChanged});

  final int servings;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: l10n.recipeLess,
          onPressed: servings > 1 ? () => onChanged(servings - 1) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        Expanded(
          child: Text(
            l10n.recipeServings(servings),
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        IconButton.filledTonal(
          tooltip: l10n.recipeMore,
          onPressed: servings < 99 ? () => onChanged(servings + 1) : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}
