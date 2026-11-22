import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/format.dart';
import '../../ui/illustrations.dart';
import '../../ui/layout.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import '../../ui/widgets/hint_card.dart';
import '../../ui/werkzeug.dart';
import '../../ui/widgets/speed_slider.dart';
import '../kochen/programs.dart';
import '../rezepte/recipe_library.dart';
import 'als_rezept.dart';
import 'assistent.dart';
import 'katalog.dart';
import 'sicherheit.dart';

/// Einheitlicher Ablauf aller Assistenten: eine Frage je Seite mit großen Kacheln (Vorschlag ist
/// vorausgewählt, „Weiter“ übernimmt ihn), danach das Ergebnis mit Zutaten, Ablauf und „Starten“.
class AssistentPage extends ConsumerStatefulWidget {
  const AssistentPage({super.key, required this.assistent});

  final Assistent assistent;

  @override
  ConsumerState<AssistentPage> createState() => _AssistentPageState();
}

class _AssistentPageState extends ConsumerState<AssistentPage> {
  final Antworten _antworten = {};
  int _seite = 0;
  bool _startet = false;

  Assistent get _as => widget.assistent;
  bool get _ergebnis => _seite >= _as.fragen.length;

  void _waehle(Frage f, Object wert) => setState(() {
    _antworten[f.id] = wert;
    _seite++;
  });

  void _zurueck() {
    if (_seite == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _seite--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final n = _as.fragen.length;
    return PopScope(
      canPop: _seite == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _zurueck();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_as.titel(l10n)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: l10n.asBack,
            onPressed: _zurueck,
          ),
          actions: [
            // Ein Tipp zurück zum Koch-Tab, egal bei welcher Frage
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: l10n.asClose,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: LinearProgressIndicator(
              value: (_seite + 1) / (n + 1),
              minHeight: 6,
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(_seite),
            child: _ergebnis ? _buildErgebnis(context) : _buildFrage(context),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Frage

  Widget _buildFrage(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final f = _as.fragen[_seite];
    final optionen = f.optionen(_antworten);
    final gewaehlt = _antworten[f.id] ?? f.standard(_antworten);
    return AdaptivePage(
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.asQuestionOf(_seite + 1, _as.fragen.length),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Tokens.s),
          Text(f.titel(l10n), style: theme.textTheme.headlineSmall),
          if (f.detail != null) ...[
            const SizedBox(height: Tokens.s),
            Text(
              f.detail!(l10n),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: Tokens.l),
          _KachelRaster(
            children: [
              for (final o in optionen)
                _Kachel(
                  text: o.text(l10n),
                  detail: o.detail?.call(l10n),
                  bild: o.bild,
                  gewaehlt: o.wert == gewaehlt,
                  onTap: () => _waehle(f, o.wert),
                ),
            ],
          ),
        ],
      ),
      bottom: BigButton(
        label: l10n.asNext,
        icon: Icons.arrow_forward_rounded,
        onPressed: () => _waehle(f, gewaehlt),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Ergebnis

  Widget _buildErgebnis(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final plan = _as.plan(_antworten);
    final caps = ref.watch(bridgeInfoProvider).value?.readyCaps;
    final busy = ref.watch(sequenceProvider).value?.active ?? false;
    final sicherheit = ref.watch(sicherheitsHinweiseProvider);
    final name = _as.programmName(l10n, _antworten);
    final program = caps == null
        ? null
        : programmAusPlan(plan, name: name, caps: caps, l10n: l10n);
    final hinweise = [
      for (final h in plan.hinweise)
        if (zeigeHinweis(h, sicherheit)) h,
    ];

    final ueberschrift = TextStyle(
      fontSize: theme.textTheme.titleLarge?.fontSize,
      fontWeight: FontWeight.w600,
    );

    final links = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Illustration(_as.bild, size: 64),
            const SizedBox(width: Tokens.m),
            Expanded(child: Text(name, style: theme.textTheme.headlineSmall)),
          ],
        ),
        const SizedBox(height: Tokens.m),
        Wrap(
          spacing: Tokens.s,
          runSpacing: Tokens.s,
          children: [
            for (final (i, f) in _as.fragen.indexed)
              ActionChip(
                avatar: const Icon(Icons.edit_rounded, size: 18),
                label: Text(_antwortText(l10n, f)),
                onPressed: () => setState(() => _seite = i),
              ),
          ],
        ),
        const SizedBox(height: Tokens.l),
        Text(l10n.asIngredients, style: ueberschrift),
        const SizedBox(height: Tokens.s),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Tokens.s),
            child: Column(
              children: [
                for (final z in plan.zutaten)
                  ListTile(
                    leading: Illustration(
                      Illustrations.forName(zutatName(l10n, z)) ??
                          Illustrations.bowl,
                      size: 40,
                    ),
                    title: Text(
                      zutatName(l10n, z),
                      style: theme.textTheme.titleMedium,
                    ),
                    trailing: Text(
                      mengeText(l10n, z),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Tokens.m),
        HintCard(
          icon: Icons.handyman_rounded,
          leading: WerkzeugBild(plan.werkzeug, size: 36),
          text: l10n.asTool(werkzeugName(l10n, plan.werkzeug)),
        ),
      ],
    );

    final rechts = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.asSteps(formatDuration(plan.gesamtS)), style: ueberschrift),
        const SizedBox(height: Tokens.s),
        for (final (i, s) in plan.schritte.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Text('${i + 1}', style: theme.textTheme.labelMedium),
                ),
                const SizedBox(width: Tokens.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schrittLabel(l10n, s.art),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        _schrittZeile(context, caps, s),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: Tokens.m),
        for (final h in hinweise) ...[
          HintCard(
            icon: h.sicherheit
                ? Icons.health_and_safety_outlined
                : Icons.lightbulb_outline_rounded,
            text: hinweisText(l10n, h),
          ),
          const SizedBox(height: Tokens.s),
        ],
        Text(
          l10n.asProvisional,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (caps == null) ...[
          const SizedBox(height: Tokens.m),
          HintCard(
            icon: Icons.link_off_rounded,
            text: l10n.programsMachineMissing,
          ),
        ] else if (program == null) ...[
          const SizedBox(height: Tokens.m),
          HintCard(icon: Icons.block_rounded, text: l10n.startInvalid),
        ] else if (busy) ...[
          const SizedBox(height: Tokens.m),
          HintCard(icon: Icons.hourglass_top_rounded, text: l10n.programBusy),
        ],
        const SizedBox(height: Tokens.l),
        // Dauerhafte eigene Werte: als normales Rezept speichern, im Editor änderbar.
        BigButton(
          label: l10n.asSaveRecipe,
          icon: Icons.bookmark_add_outlined,
          kind: BigButtonKind.secondary,
          onPressed: _alsRezeptSpeichern,
        ),
      ],
    );

    return AdaptivePage(
      primary: links,
      secondary: rechts,
      bottom: BigButton(
        label: l10n.asStart,
        icon: Icons.play_arrow_rounded,
        busy: _startet,
        onPressed: program == null || busy ? null : () => _starte(program),
      ),
    );
  }

  /// Dialog mit Titelvorschlag; der Dialog bleibt bei Fehlern offen (nichts geht verloren).
  Future<void> _alsRezeptSpeichern() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final id = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RezeptSpeichernDialog(
        vorschlag: _as.rezeptTitel(l10n),
        speichern: _speichere,
      ),
    );
    if (id == null || !mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.asSaveDone),
        action: SnackBarAction(
          label: l10n.asSaveOpen,
          onPressed: () => router.go('/rezepte/$id'),
        ),
      ),
    );
  }

  /// Rezept anlegen; bei Fehlern [_SpeichernFehler] mit der Meldung für den Dialog.
  /// [id] bleibt für alle Versuche im Dialog gleich: Kam die Antwort nicht an, obwohl die Brücke
  /// gespeichert hat, meldet sie beim nächsten Versuch einen Konflikt – dann ist es schon da.
  Future<void> _speichere(String id, String titel) async {
    final l10n = context.l10n;
    final info = ref.read(bridgeInfoProvider).value;
    final caps = info?.readyCaps ?? info?.appliance?.caps;
    if (info == null) throw _SpeichernFehler(l10n.bridgeUnreachable);
    if (caps == null) throw _SpeichernFehler(l10n.asSaveNoMachine);
    final rezept = rezeptAusPlan(
      _as.plan(_antworten),
      id: id,
      titel: titel,
      portionen: _as.portionen(_antworten),
      caps: caps,
      l10n: l10n,
      jetzt: DateTime.now(),
    );
    if (rezept == null) throw _SpeichernFehler(l10n.asSaveInvalid);
    final library = ref.read(recipeLibraryProvider.notifier);
    try {
      final result = await library.save(rezept);
      if (result is RecipeConflict) {
        if (result.currentRev > 0 && !result.deleted) {
          await library.sync(); // früherer Versuch ist doch angekommen
          return;
        }
        throw _SpeichernFehler(l10n.asSaveFailed);
      }
    } on BridgeException catch (e) {
      throw _SpeichernFehler(
        e.kind == BridgeErrorKind.rejected
            ? l10n.editorSaveRejected(e.code ?? '${e.statusCode}')
            : l10n.bridgeUnreachable,
      );
    }
  }

  String _antwortText(AppLocalizations l10n, Frage f) {
    final wert = _antworten[f.id] ?? f.standard(_antworten);
    for (final o in f.optionen(_antworten)) {
      if (o.wert == wert) return o.text(l10n);
    }
    return '$wert';
  }

  String _schrittZeile(
    BuildContext context,
    ApplianceCaps? caps,
    PlanSchritt s,
  ) {
    final l10n = context.l10n;
    final zeit = formatDuration(s.zeitS);
    if (s.ruhe) return l10n.asRestLine(zeit);
    final v = caps == null ? null : s.stufe.aufloesen(caps);
    final stufe = v == null
        ? (s.stufe.gruppe == SpeedGroup.stir
              ? '${l10n.speedGroupStir} ${s.stufe.label}'
              : l10n.testStepSpeed(s.stufe.label))
        : speedText(context, caps, v);
    return s.temperatur > 0
        ? l10n.programStepLineHeat(stufe, zeit, s.temperatur)
        : l10n.programStepLine(stufe, zeit);
  }

  Future<void> _starte(Program program) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _startet = true);
    final fehler = await ref
        .read(sequenceControllerProvider)
        .start(program, l10n);
    if (!mounted) return;
    setState(() => _startet = false);
    if (fehler != null) {
      messenger.showSnackBar(SnackBar(content: Text(fehler)));
      return;
    }
    // Zurück zum Kochen-Tab: dort zeigt die Programm-Karte den Lauf („Knopf drücken“).
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.asStarted)));
  }
}

// ---------------------------------------------------------------------------
// Als Rezept speichern

class _SpeichernFehler implements Exception {
  const _SpeichernFehler(this.meldung);
  final String meldung;
}

/// Titel ändern und speichern. Schließt sich erst nach dem Speichern (mit der Rezept-ID);
/// Fehler stehen im Dialog, der Titel bleibt stehen.
class _RezeptSpeichernDialog extends StatefulWidget {
  const _RezeptSpeichernDialog({
    required this.vorschlag,
    required this.speichern,
  });

  final String vorschlag;
  final Future<void> Function(String id, String titel) speichern;

  @override
  State<_RezeptSpeichernDialog> createState() => _RezeptSpeichernDialogState();
}

class _RezeptSpeichernDialogState extends State<_RezeptSpeichernDialog> {
  late final _titel = TextEditingController(text: widget.vorschlag);
  final _id = newRecipeId();
  bool _speichert = false;
  String? _fehler;

  @override
  void dispose() {
    _titel.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    final l10n = context.l10n;
    final titel = _titel.text.trim();
    if (titel.isEmpty) {
      setState(() => _fehler = l10n.asSaveNameMissing);
      return;
    }
    setState(() {
      _speichert = true;
      _fehler = null;
    });
    try {
      await widget.speichern(_id, titel);
      if (mounted) Navigator.of(context).pop(_id);
    } on _SpeichernFehler catch (e) {
      if (mounted) {
        setState(() {
          _speichert = false;
          _fehler = e.meldung;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.asSaveRecipe),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titel,
            autofocus: true,
            maxLength: rezeptTitelMaxBytes,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.asSaveName),
            onSubmitted: (_) => _speichert ? null : _speichern(),
          ),
          Text(
            l10n.asSaveHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_fehler != null) ...[
            const SizedBox(height: Tokens.m),
            Text(
              _fehler!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _speichert ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.asSaveCancel),
        ),
        FilledButton(
          onPressed: _speichert ? null : _speichern,
          child: _speichert
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.asSaveConfirm),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kacheln

/// Zwei Spalten auf dem Handy, drei auf breiteren Fenstern.
class _KachelRaster extends StatelessWidget {
  const _KachelRaster({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = c.maxWidth >= 560 ? 3 : 2;
      final width = (c.maxWidth - (columns - 1) * Tokens.m) / columns;
      return Wrap(
        spacing: Tokens.m,
        runSpacing: Tokens.m,
        children: [for (final k in children) SizedBox(width: width, child: k)],
      );
    },
  );
}

class _Kachel extends StatelessWidget {
  const _Kachel({
    required this.text,
    required this.gewaehlt,
    required this.onTap,
    this.detail,
    this.bild,
  });

  final String text;
  final String? detail;
  final String? bild;
  final bool gewaehlt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      selected: gewaehlt,
      button: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: gewaehlt ? scheme.primaryContainer : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radius),
          side: BorderSide(
            color: gewaehlt ? scheme.primary : scheme.outlineVariant,
            width: gewaehlt ? 3 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.all(Tokens.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (bild != null) ...[
                        Illustration(bild!, size: 36),
                        const SizedBox(width: Tokens.s),
                      ],
                      Expanded(
                        child: Text(
                          text,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: gewaehlt ? scheme.onPrimaryContainer : null,
                          ),
                        ),
                      ),
                      if (gewaehlt)
                        Icon(Icons.check_circle_rounded, color: scheme.primary),
                    ],
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: gewaehlt
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
