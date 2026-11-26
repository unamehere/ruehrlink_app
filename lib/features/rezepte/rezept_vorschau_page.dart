import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../l10n/l10n.dart';
import '../../ui/layout.dart';
import '../../ui/theme.dart';
import '../../ui/werkzeug.dart';
import '../../ui/widgets/big_button.dart';
import '../../ui/widgets/hint_card.dart';
import '../kochen/programs.dart';
import 'recipe_library.dart';
import 'recipe_widgets.dart';
import 'rezept_datei.dart';
import 'rezept_teilen.dart';

/// Vorschau einer Rezept-Datei (geteilt oder gewählt): Foto, Titel, Zutaten, Schritte, Hinweise →
/// „In meine Rezepte übernehmen“. Übernommen wird immer als neues Rezept.
class RezeptVorschauPage extends ConsumerStatefulWidget {
  const RezeptVorschauPage({super.key});

  @override
  ConsumerState<RezeptVorschauPage> createState() => _RezeptVorschauPageState();
}

class _RezeptVorschauPageState extends ConsumerState<RezeptVorschauPage> {
  RezeptEingang? _eingang;
  RezeptDatei? _datei;
  RezeptDateiFehler? _fehler;
  bool _saving = false;
  String? _saveError;

  void _lesen(RezeptEingang? e) {
    _eingang = e;
    _datei = null;
    _fehler = null;
    _saveError = null;
    if (e == null) return;
    try {
      _datei = RezeptDatei.lesen(e.bytes);
    } on RezeptDateiException catch (x) {
      _fehler = x.fehler;
    }
  }

  void _schliessen() {
    ref.read(rezeptEingangProvider.notifier).set(null);
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/rezepte');
    }
  }

  Future<void> _uebernehmen(RezeptDatei d) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final r = await ref.read(recipeLibraryProvider.notifier).uebernehmen(d);
      // Datei nicht leeren: die Seite wird gerade ersetzt und soll bis dahin die Vorschau zeigen.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.recipeFileImported(r.title))),
      );
      router.go('/rezepte/${r.id}');
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(
        () => _saveError = e.kind == BridgeErrorKind.rejected
            ? l10n.recipeFileRejected(e.code ?? '${e.statusCode}')
            : l10n.recipeFileOffline,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final eingang = ref.watch(rezeptEingangProvider);
    if (!identical(eingang, _eingang)) _lesen(eingang);
    final d = _datei;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recipeFileImportTitle),
        leading: CloseButton(onPressed: _schliessen),
      ),
      body: d == null ? _error(context) : _preview(context, d),
    );
  }

  Widget _error(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final text = _eingang == null
        ? l10n.recipeFileReadFailed
        : switch (_fehler) {
            RezeptDateiFehler.leer => l10n.recipeFileEmpty,
            RezeptDateiFehler.zuGross => l10n.recipeFileTooBig,
            RezeptDateiFehler.rezeptZuGross => l10n.recipeFileRecipeTooBig,
            _ => l10n.recipeFileBroken,
          };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: Tokens.m),
            Text(
              text,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (_eingang?.name case final name? when name.isNotEmpty) ...[
              const SizedBox(height: Tokens.s),
              Text(
                name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _preview(BuildContext context, RezeptDatei d) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final recipe = d.recipe;
    final caps = ref.watch(bridgeInfoProvider).value?.readyCaps;
    final programs = ref.watch(bridgeProgramsProvider).value;
    final titles = ref.watch(
      recipeLibraryProvider.select(
        (s) => [for (final r in s.recipes.values) r.title],
      ),
    );
    final newTitle = freierTitel(recipe.title, titles);
    final unknownPrograms = programs == null
        ? const <int>[]
        : schritteMitUnbekanntemProgramm(recipe, programs.map((p) => p.id));
    final photo = recipe.photo == null ? null : d.photos[recipe.photo];
    final h = d.hinweise;

    final hints = <String>[
      if (h.neueresFormat) l10n.recipeFileHintNewer,
      if (h.unbekannteWerkzeuge.isNotEmpty)
        l10n.recipeFileHintTools(h.unbekannteWerkzeuge.length),
      if (unknownPrograms.isNotEmpty)
        l10n.recipeFileHintPrograms(unknownPrograms.length),
      if (h.fehlendeFotos > 0) l10n.recipeFileHintPhotos(h.fehlendeFotos),
      if (h.gekuerzt) l10n.recipeFileHintShortened,
    ];

    final primary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Tokens.radius),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: photo != null
                ? Image.memory(
                    photo,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        RecipeIllustration(title: recipe.title),
                  )
                : RecipeIllustration(title: recipe.title),
          ),
        ),
        const SizedBox(height: Tokens.m),
        Text(recipe.title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: Tokens.s / 2),
        Text(
          l10n.recipeServings(recipe.servings),
          style: theme.textTheme.bodyLarge,
        ),
        if (newTitle != recipe.title.trim()) ...[
          const SizedBox(height: Tokens.s),
          Text(
            l10n.recipeFileTitleTaken(newTitle),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        for (final text in hints)
          Padding(
            padding: const EdgeInsets.only(top: Tokens.s),
            child: HintCard(icon: Icons.info_outline_rounded, text: text),
          ),
        const SizedBox(height: Tokens.l),
        Text(l10n.recipeIngredients, style: theme.textTheme.headlineSmall),
        const SizedBox(height: Tokens.s),
        for (final i in recipe.ingredients)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ingredientText(i, 1),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
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
                      if (s.tool case final t?
                          when t != werkzeugVor(recipe.steps, n))
                        Text(
                          l10n.toolInsert(werkzeugName(l10n, t)),
                          style: theme.textTheme.bodyMedium,
                        ),
                      if (h.unbekannteWerkzeuge.contains(n + 1))
                        Text(l10n.recipeFileUnknownTool, style: muted),
                      if (s.text.isNotEmpty)
                        Text(s.text, style: theme.textTheme.bodyLarge),
                      if (s.ingredients.isNotEmpty)
                        Text(
                          [for (final i in s.ingredients) ingredientText(i, 1)]
                              .join(' · '),
                          style: muted,
                        ),
                      if (stepSummary(
                            context,
                            s,
                            factor: 1,
                            caps: caps,
                            programs: programs ?? const [],
                          )
                          case final summary?)
                        Text(
                          summary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
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

    return AdaptivePage(
      primary: primary,
      secondary: secondary,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_saveError case final e?)
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.s),
              child: Text(
                e,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          BigButton(
            label: l10n.recipeFileImport,
            icon: Icons.download_done_rounded,
            busy: _saving,
            onPressed: () => _uebernehmen(d),
          ),
        ],
      ),
    );
  }
}
