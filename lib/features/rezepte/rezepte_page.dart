import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/illustrations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import 'recipe_library.dart';
import 'recipe_widgets.dart';

/// Rezepte-Tab: Suche, Tags, Raster mit Fotos. Antippen → Rezeptseite.
class RezeptePage extends ConsumerStatefulWidget {
  const RezeptePage({super.key});

  @override
  ConsumerState<RezeptePage> createState() => _RezeptePageState();
}

class _RezeptePageState extends ConsumerState<RezeptePage> {
  final _search = TextEditingController();
  String? _tag;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Recipe> _filter(List<Recipe> all) {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final r in all)
        if ((_tag == null || r.tags.contains(_tag)) &&
            (q.isEmpty ||
                r.title.toLowerCase().contains(q) ||
                r.tags.any((t) => t.toLowerCase().contains(q)) ||
                r.ingredients.any((i) => i.name.toLowerCase().contains(q))))
          r,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final lib = ref.watch(recipeLibraryProvider);
    final tags = lib.tags;
    if (_tag != null && !tags.contains(_tag)) _tag = null;
    final shown = _filter(lib.sorted);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabRezepte)),
      floatingActionButton: lib.recipes.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go('/rezepte/neu'),
              icon: const Icon(Icons.add_rounded, size: 30),
              label: Text(l10n.recipesNew, style: theme.textTheme.labelLarge),
            ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(recipeLibraryProvider.notifier).sync(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.m,
                0,
                Tokens.m,
                Tokens.s,
              ),
              sliver: SliverList.list(
                children: [
                  if (lib.offline)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Tokens.s),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: Tokens.s),
                          Expanded(
                            child: Text(
                              l10n.recipesOffline,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (lib.recipes.isNotEmpty) ...[
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: l10n.recipesSearch,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: l10n.cancel,
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () =>
                                    setState(() => _search.clear()),
                              ),
                      ),
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: Tokens.s),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final t in [null, ...tags])
                              Padding(
                                padding: const EdgeInsets.only(right: Tokens.s),
                                child: ChoiceChip(
                                  label: Text(t ?? l10n.recipesAllTags),
                                  labelStyle: theme.textTheme.labelMedium,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Tokens.s,
                                    vertical: 10,
                                  ),
                                  selected: _tag == t,
                                  onSelected: (_) => setState(() => _tag = t),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            if (lib.recipes.isEmpty && lib.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (lib.recipes.isEmpty)
              const SliverFillRemaining(hasScrollBody: false, child: _Empty())
            else if (shown.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(Tokens.xl),
                  child: Text(
                    l10n.recipesNoMatch,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              SliverPadding(
                // unten Platz für den schwebenden Button
                padding: const EdgeInsets.fromLTRB(
                  Tokens.m,
                  Tokens.s,
                  Tokens.m,
                  96,
                ),
                sliver: SliverLayoutBuilder(
                  builder: (context, c) {
                    final w = c.crossAxisExtent;
                    final columns = w >= 1000
                        ? 4
                        : w >= 640
                        ? 3
                        : 2;
                    return SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: Tokens.m,
                        crossAxisSpacing: Tokens.m,
                        // Bild 4:3 + zwei Zeilen Titel + eine Zeile Info
                        mainAxisExtent:
                            (w - (columns - 1) * Tokens.m) / columns * 3 / 4 +
                            118,
                      ),
                      itemCount: shown.length,
                      itemBuilder: (context, i) =>
                          _RecipeTile(recipe: shown[i]),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/rezepte/${recipe.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RecipeImage(recipe: recipe),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.m - 4,
                Tokens.s,
                Tokens.m - 4,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    l10n.recipeStepsCount(recipe.steps.length),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Tokens.maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.all(Tokens.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Illustration(Illustrations.cooking, size: 96),
              const SizedBox(height: Tokens.l),
              Text(
                l10n.recipesEmpty,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Tokens.s),
              Text(
                l10n.recipesEmptyHint,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Tokens.l),
              BigButton(
                label: l10n.recipesNew,
                icon: Icons.add_rounded,
                onPressed: () => context.go('/rezepte/neu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
