import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_providers.dart';
import '../../core/event_log.dart';
import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/format.dart';
import '../../ui/illustrations.dart';
import '../../ui/layout.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import '../../ui/widgets/hint_card.dart';
import '../../ui/widgets/speed_slider.dart';
import '../../ui/werkzeug.dart';
import '../assistenten/sicherheit.dart';
import '../kochen/programs.dart';
import 'recipe_library.dart';
import 'weigh_step_slot.dart';

/// Kochmodus: ein Schritt pro Bildschirm, große Knöpfe, „Weiter“.
///
/// Seiten: Bereitstellen (Zutaten) → Schritte → Fertig. Maschinenschritte startet er über den
/// Sequencer der Brücke (`POST /sequence/start`, gestartet wird am Gerät); ist der Schritt
/// fertig, blättert er von selbst weiter. Wiegeschritte zeigen [WeighStepSlot].
class KochmodusPage extends ConsumerStatefulWidget {
  const KochmodusPage({super.key, required this.id, this.servings});

  final String id;

  /// Portionen von der Rezeptseite; `null` = wie im Rezept.
  final int? servings;

  @override
  ConsumerState<KochmodusPage> createState() => _KochmodusPageState();
}

class _KochmodusPageState extends ConsumerState<KochmodusPage> {
  final _pages = PageController();
  int _page = 0;

  /// Seite, auf der ein Maschinenschritt gestartet wurde (für „automatisch weiter“).
  int? _startedOn;
  bool _sending = false;
  final _weighReached = <int>{};

  @override
  void initState() {
    super.initState();
    appEvents.add('kochmodus', 'geöffnet (Rezept ${widget.id})');
  }

  @override
  void dispose() {
    appEvents.add('kochmodus', 'geschlossen auf Seite ${_page + 1}');
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) => _pages.animateToPage(
    page,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );

  void _close() =>
      context.canPop() ? context.pop() : context.go('/rezepte/${widget.id}');

  Future<void> _start(Recipe recipe, RecipeStep step) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final m = step.machine!;
    Program? program;
    if (m.programId case final id?) {
      final programs = await ref.read(bridgeProgramsProvider.future);
      program = programs.where((p) => p.id == id).firstOrNull;
      if (program == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.cookProgramMissing(id))),
        );
        return;
      }
    } else {
      program = Program(
        id: '',
        name: fitUtf8(recipe.title, 39),
        steps: [
          ProgramStep(settings: m.settings!, label: fitUtf8(step.text, 31)),
        ],
      );
    }
    setState(() => _sending = true);
    final error = await ref
        .read(sequenceControllerProvider)
        .start(program, l10n);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (error == null) _startedOn = _page;
    });
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

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
    final servings = widget.servings ?? base;
    final factor = servings / base;
    // Seiten: Bereitstellen, je Schritt ggf. erst „Werkzeug wechseln“, dann der Schritt, Fertig.
    final pages = <_Seite>[
      const _Seite.bereitstellen(),
      for (final (i, s) in recipe.steps.indexed) ...[
        if (s.tool case final t? when t != werkzeugVor(recipe.steps, i))
          _Seite.wechsel(t, werkzeugVor(recipe.steps, i)),
        _Seite.schritt(i),
      ],
      const _Seite.fertig(),
    ];
    final total = pages.length;
    final last = total - 1;

    // Maschinenschritt fertig → automatisch weiter.
    ref.listen(sequenceProvider, (prev, next) {
      final was = prev?.value, now = next.value;
      if (_startedOn == null || _startedOn != _page || now == null) return;
      if (was?.active == true && now.state == SequenceRunState.done) {
        _startedOn = null;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.cookStepDone)));
        Timer(const Duration(milliseconds: 1200), () {
          if (mounted && _page < last) _go(_page + 1);
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.cookClose,
          icon: const Icon(Icons.close_rounded),
          onPressed: _close,
        ),
        title: Text(recipe.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.m),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_page + 1) / total,
                minHeight: 8,
                color: Tokens.glow,
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: total,
              onPageChanged: (p) {
                final s = pages[p];
                appEvents.add(
                  'kochmodus',
                  'Seite ${p + 1}/$total: ${s.art.name}'
                      '${s.schritt != null ? ' ${s.schritt! + 1}' : ''}',
                );
                setState(() => _page = p);
              },
              itemBuilder: (context, p) {
                final seite = pages[p];
                if (seite.art == _Art.bereitstellen) {
                  return _PreparePage(recipe: recipe, factor: factor);
                }
                if (seite.art == _Art.fertig) return const _DonePage();
                if (seite.art == _Art.wechsel) {
                  return _WechselPage(neu: seite.neu!, alt: seite.alt);
                }
                final step = recipe.steps[seite.schritt!];
                return _StepPage(
                  key: ValueKey(p),
                  recipe: recipe,
                  step: step,
                  number: seite.schritt! + 1,
                  of: recipe.steps.length,
                  factor: factor,
                  toolChange: null,
                  startedHere: _startedOn == p,
                  sending: _sending,
                  onStart: () => _start(recipe, step),
                  onWeighReached: () => setState(() => _weighReached.add(p)),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: Tokens.maxTwoPaneWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.m,
                    Tokens.s,
                    Tokens.m,
                    Tokens.m,
                  ),
                  child: Row(
                    children: [
                      if (_page > 0) ...[
                        Expanded(
                          child: BigButton(
                            label: l10n.back,
                            icon: Icons.arrow_back_rounded,
                            kind: BigButtonKind.secondary,
                            onPressed: () => _go(_page - 1),
                          ),
                        ),
                        const SizedBox(width: Tokens.m),
                      ],
                      Expanded(
                        flex: 2,
                        child: _page == last
                            ? BigButton(
                                label: l10n.cookFinish,
                                icon: Icons.check_rounded,
                                onPressed: _close,
                              )
                            : BigButton(
                                label: pages[_page].art == _Art.wechsel
                                    ? l10n.toolSwapDone
                                    : l10n.cookNext,
                                icon: _weighReached.contains(_page)
                                    ? Icons.check_circle_rounded
                                    : Icons.arrow_forward_rounded,
                                onPressed: () => _go(_page + 1),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Art { bereitstellen, wechsel, schritt, fertig }

/// Eine Seite im Kochmodus.
class _Seite {
  const _Seite.bereitstellen()
    : art = _Art.bereitstellen,
      schritt = null,
      neu = null,
      alt = null;
  const _Seite.fertig()
    : art = _Art.fertig,
      schritt = null,
      neu = null,
      alt = null;
  const _Seite.schritt(int this.schritt)
    : art = _Art.schritt,
      neu = null,
      alt = null;
  const _Seite.wechsel(Werkzeug this.neu, this.alt)
    : art = _Art.wechsel,
      schritt = null;

  final _Art art;
  final int? schritt;
  final Werkzeug? neu;
  final Werkzeug? alt;
}

/// „Werkzeug wechseln“: eigene Seite, nur wenn sich das Werkzeug gegenüber dem vorigen Schritt ändert.
class _WechselPage extends StatelessWidget {
  const _WechselPage({required this.neu, this.alt});

  final Werkzeug neu;
  final Werkzeug? alt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = werkzeugName(l10n, neu);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Tokens.l),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Tokens.maxContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.toolSwapTitle.toUpperCase(),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: Tokens.l),
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: WerkzeugBild(
                  neu,
                  size: 112,
                  background: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: Tokens.l),
              Text(
                l10n.toolInsert(name),
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Tokens.s),
              Text(
                alt == null
                    ? l10n.toolSwapHintFirst(name)
                    : l10n.toolSwapHint(werkzeugName(l10n, alt!), name),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreparePage extends StatelessWidget {
  const _PreparePage({required this.recipe, required this.factor});

  final Recipe recipe;
  final double factor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AdaptivePage(
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.cookPrepare, style: theme.textTheme.headlineMedium),
          const SizedBox(height: Tokens.s),
          Text(
            l10n.recipeServings((recipe.servings * factor).round()),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Tokens.m),
          for (final i in recipe.ingredients)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Illustration(
                    Illustrations.forName(i.name) ?? Illustrations.bowl,
                    size: 48,
                  ),
                  const SizedBox(width: Tokens.m),
                  Expanded(
                    child: Text(
                      ingredientText(i, factor),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DonePage extends StatelessWidget {
  const _DonePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdaptivePage(
      primary: Column(
        children: [
          const SizedBox(height: Tokens.xl),
          const Illustration(Illustrations.cooking, size: 120),
          const SizedBox(height: Tokens.l),
          Text(
            context.l10n.cookDoneTitle,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Tokens.s),
          Text(
            context.l10n.cookDoneText,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Ein Schritt: ggf. „Werkzeug einsetzen“, Text (groß), Zutaten, optional Foto; daneben bzw.
/// darunter die Waage (Gramm-Zutaten nacheinander) und die Maschine.
class _StepPage extends StatelessWidget {
  const _StepPage({
    super.key,
    required this.recipe,
    required this.step,
    required this.number,
    required this.of,
    required this.factor,
    required this.toolChange,
    required this.startedHere,
    required this.sending,
    required this.onStart,
    required this.onWeighReached,
  });

  final Recipe recipe;
  final RecipeStep step;
  final int number;
  final int of;
  final double factor;

  /// Werkzeug, das jetzt neu eingesetzt werden muss (`null` = kein Wechsel).
  final Werkzeug? toolChange;
  final bool startedHere;
  final bool sending;
  final VoidCallback onStart;
  final VoidCallback onWeighReached;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ingredients = [for (final i in step.ingredients) i.scaled(factor)];
    final toWeigh = [
      for (final i in ingredients)
        if (i.grams != null) i,
    ];
    final machine = step.machine != null
        ? _MachinePanel(
            step: step,
            startedHere: startedHere,
            sending: sending,
            onStart: onStart,
          )
        : null;
    final Widget? side = toWeigh.isEmpty
        ? machine
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WeighSequence(
                ingredients: toWeigh,
                onAllReached: onWeighReached,
              ),
              if (machine != null) ...[
                const SizedBox(height: Tokens.l),
                machine,
              ],
            ],
          );
    return AdaptivePage(
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.seqStep(number, of),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Tokens.s),
          if (toolChange case final t?) ...[
            HintCard(
              icon: Icons.handyman_rounded,
              leading: WerkzeugBild(t, size: 36),
              text: l10n.toolInsert(werkzeugName(l10n, t)),
            ),
            const SizedBox(height: Tokens.m),
          ],
          if (step.text.isNotEmpty)
            Text(step.text, style: theme.textTheme.headlineMedium),
          if (ingredients.isNotEmpty) ...[
            const SizedBox(height: Tokens.m),
            Text(
              l10n.cookIngredients,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            for (final i in ingredients)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Illustration(
                      Illustrations.forName(i.name) ?? Illustrations.bowl,
                      size: 40,
                    ),
                    const SizedBox(width: Tokens.m),
                    Expanded(
                      child: Text(
                        ingredientText(i, 1),
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (step.photo case final sha?) ...[
            const SizedBox(height: Tokens.m),
            ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.radius),
              child: _StepPhoto(sha: sha),
            ),
          ],
        ],
      ),
      secondary: side,
    );
  }
}

/// Waage für alle Gramm-Zutaten eines Schritts, eine nach der anderen. Jede Zutat bekommt eine
/// eigene Waage-Ansicht (Key = Index) und damit ihre eigene Tara.
class _WeighSequence extends StatefulWidget {
  const _WeighSequence({required this.ingredients, required this.onAllReached});

  final List<Ingredient> ingredients;
  final VoidCallback onAllReached;

  @override
  State<_WeighSequence> createState() => _WeighSequenceState();
}

class _WeighSequenceState extends State<_WeighSequence> {
  int _i = 0;
  bool _reached = false;

  void _next() {
    if (_i + 1 >= widget.ingredients.length) return;
    setState(() {
      _i++;
      _reached = false;
    });
  }

  void _onReached() {
    setState(() => _reached = true);
    if (_i + 1 >= widget.ingredients.length) widget.onAllReached();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final n = widget.ingredients.length;
    final last = _i + 1 >= n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (n > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.s),
            child: Text(
              '${_i + 1} / $n',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        WeighStepSlot(
          key: ValueKey(_i),
          ingredient: widget.ingredients[_i],
          onReached: _onReached,
        ),
        if (!last) ...[
          const SizedBox(height: Tokens.m),
          BigButton(
            label: l10n.cookWeighNext,
            icon: Icons.arrow_forward_rounded,
            kind: _reached ? BigButtonKind.primary : BigButtonKind.secondary,
            onPressed: _next,
          ),
        ] else if (_reached && n > 1) ...[
          const SizedBox(height: Tokens.m),
          Text(
            l10n.cookWeighAllDone,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ],
    );
  }
}

class _StepPhoto extends ConsumerWidget {
  const _StepPhoto({required this.sha});
  final String sha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(recipePhotoProvider(sha)).value;
    if (bytes == null) return const SizedBox.shrink();
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Image.memory(bytes, fit: BoxFit.cover),
    );
  }
}

/// Maschinenschritt: Werte groß, „An die Maschine senden“, danach Zustand des Programms
/// und ein großer Stopp-Button.
class _MachinePanel extends ConsumerWidget {
  const _MachinePanel({
    required this.step,
    required this.startedHere,
    required this.sending,
    required this.onStart,
  });

  final RecipeStep step;
  final bool startedHere;
  final bool sending;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final info = ref.watch(bridgeInfoProvider).value;
    // Gestartet wird als Programm – ohne Fähigkeit `sequence` geht der Knopf aus.
    final caps = (info?.has('sequence') ?? false) ? info?.readyCaps : null;
    final seq = ref.watch(sequenceProvider).value;
    final m = step.machine!;
    final v = m.settings;
    final hot =
        v != null &&
        v.temperature > 0 &&
        v.temperature >= (caps?.hotTemp ?? 60);
    final showHot =
        hot &&
        ref.watch(sicherheitsHinweiseProvider) != SicherheitsHinweise.aus;

    final values = v == null
        ? _programInfo(context, ref, m.programId!)
        : Row(
            children: [
              Expanded(
                child: _BigValue(
                  label: l10n.dialTemperature,
                  value: v.temperature > 0
                      ? l10n.temperatureValue(v.temperature)
                      : l10n.valueOff,
                ),
              ),
              Expanded(
                child: _BigValue(
                  label: l10n.dialTime,
                  value: formatDuration(v.time),
                ),
              ),
              Expanded(
                child: _BigValue(
                  label: l10n.dialSpeed,
                  value: caps?.speedLabel(v.speed) ?? '${v.speed}',
                  detail: speedText(context, caps, v.speed),
                ),
              ),
            ],
          );

    final children = <Widget>[
      Card(
        child: Padding(padding: const EdgeInsets.all(Tokens.m), child: values),
      ),
      if (showHot) ...[
        const SizedBox(height: Tokens.s),
        // Dezent, abschaltbar unter Mehr → Hinweise beim Kochen.
        Row(
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Tokens.s),
            Expanded(
              child: Text(
                l10n.cookHotHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: Tokens.m),
    ];

    if (seq != null && seq.active) {
      children.addAll([
        _SeqStatus(seq: seq),
        const SizedBox(height: Tokens.m),
        BigButton.stop(
          label: l10n.seqAbort,
          onPressed: () => ref.read(sequenceControllerProvider).abort(),
        ),
      ]);
    } else {
      if (startedHere && seq?.state == SequenceRunState.done) {
        children.addAll([
          HintCard(icon: Icons.check_circle_rounded, text: l10n.seqDone),
          const SizedBox(height: Tokens.m),
        ]);
      }
      if (caps == null) {
        children.addAll([
          HintCard(
            icon: Icons.link_off_rounded,
            text: l10n.programsMachineMissing,
          ),
          const SizedBox(height: Tokens.m),
        ]);
      }
      children.add(
        BigButton(
          label: l10n.cookSend,
          icon: Icons.play_arrow_rounded,
          busy: sending,
          onPressed: caps == null ? null : onStart,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _programInfo(BuildContext context, WidgetRef ref, String id) {
    final theme = Theme.of(context);
    final programs = ref.watch(bridgeProgramsProvider).value ?? const [];
    final p = programs.where((p) => p.id == id).firstOrNull;
    return Row(
      children: [
        Illustration(
          Illustrations.forName(p?.name ?? id) ?? Illustrations.bowl,
        ),
        const SizedBox(width: Tokens.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p?.name ?? id, style: theme.textTheme.titleLarge),
              if (p != null)
                Text(
                  context.l10n.programStepsInfo(
                    p.steps.length,
                    formatDuration(p.totalTime),
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BigValue extends StatelessWidget {
  const _BigValue({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: theme.textTheme.headlineMedium),
        ),
        if (detail != null && detail != value)
          Text(
            detail!,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
      ],
    );
  }
}

/// Zustand des laufenden Programms in einer Zeile bzw. mit Restzeit.
class _SeqStatus extends StatelessWidget {
  const _SeqStatus({required this.seq});

  final SequenceState seq;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (seq.state == SequenceRunState.running) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.m),
          child: Column(
            children: [
              Text(l10n.seqRunning, style: theme.textTheme.titleMedium),
              Text(
                formatDuration(seq.stepRemainingS),
                style: theme.textTheme.displaySmall,
              ),
            ],
          ),
        ),
      );
    }
    final text = switch ((seq.state, seq.reason)) {
      (SequenceRunState.waitingStart, _) => l10n.seqPressStart,
      (SequenceRunState.paused, 'lid_open') => l10n.seqLidOpen,
      (SequenceRunState.paused, 'bowl_missing') => l10n.seqBowlMissing,
      (SequenceRunState.paused, 'machine_paused') => l10n.seqMachinePaused,
      _ => l10n.seqPaused,
    };
    return HintCard(
      icon: seq.state == SequenceRunState.waitingStart
          ? Icons.touch_app_rounded
          : Icons.pause_circle_rounded,
      text: text,
      emphasized: true,
    );
  }
}
