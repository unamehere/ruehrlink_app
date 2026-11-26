import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/format.dart';
import '../../ui/hilfe_knopf.dart';
import '../../ui/input.dart';
import '../../ui/layout.dart';
import '../../ui/theme.dart';
import '../../ui/werkzeug.dart';
import '../../ui/widgets/big_button.dart';
import '../../ui/widgets/speed_slider.dart';
import '../hilfe/hilfe_themen.dart';
import 'photo_picker.dart';
import 'recipe_library.dart';
import 'recipe_widgets.dart';

/// Einfacher Rezept-Editor: Titel, Portionen, Tags, Foto, Zutaten, Schritte
/// (Text, optional Wiegen oder Maschine – Programm oder Einzelwerte).
/// [id] `null` = neues Rezept.
class RecipeEditorPage extends ConsumerStatefulWidget {
  const RecipeEditorPage({super.key, this.id});

  final String? id;

  @override
  ConsumerState<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _IngredientRow {
  _IngredientRow([Ingredient? i])
    : amount = TextEditingController(
        text: i == null || i.amount == 0 ? '' : formatAmount(i.amount),
      ),
      unit = i?.unit.trim() ?? 'g',
      name = TextEditingController(text: i?.name ?? '');

  final TextEditingController amount, name;

  /// Aus [recipeUnits]; ältere Rezepte können eine eigene Einheit haben (bleibt wählbar).
  String unit;

  void dispose() {
    amount.dispose();
    name.dispose();
  }
}

/// Eine Phase eines Maschinenschritts (Temperatur, Zeit, Stufe).
class _PhaseRow {
  _PhaseRow([MachineSettings? m])
    : temperature = TextEditingController(text: '${m?.temperature ?? 0}'),
      time = TextEditingController(
        text: m == null ? '' : formatDuration(m.time),
      ),
      speed = m?.speed ?? 0;

  final TextEditingController temperature, time;
  int? speed;

  /// `null`, wenn Zeit oder Stufe fehlt.
  MachineSettings? get built {
    final t = parseDurationText(time.text);
    final temp = int.tryParse(temperature.text.trim()) ?? 0;
    if (t == null || t <= 0 || speed == null || temp < 0) return null;
    return MachineSettings(temperature: temp, time: t, speed: speed!);
  }

  void dispose() {
    temperature.dispose();
    time.dispose();
  }
}

class _StepRow {
  _StepRow([RecipeStep? s])
    : text = TextEditingController(text: s?.text ?? ''),
      photo = s?.photo,
      ingredients = [...?s?.ingredients.map(_IngredientRow.new)],
      tool = s?.tool,
      hasMachine = s?.machine != null,
      phases = [
        for (final m in s?.machine?.phasen ?? const <MachineSettings>[])
          _PhaseRow(m),
      ] {
    if (phases.isEmpty) phases.add(_PhaseRow());
  }

  final TextEditingController text;

  /// Phasen der Einzelwerte, mindestens eine (die zweite und weitere laufen direkt im Anschluss).
  final List<_PhaseRow> phases;
  final String?
  photo; // Schrittfotos bleiben erhalten, werden hier (noch) nicht bearbeitet
  final List<_IngredientRow> ingredients;
  Werkzeug? tool;
  bool hasMachine;

  List<Ingredient> get builtIngredients => [
    for (final r in ingredients)
      if (r.name.text.trim().isNotEmpty)
        Ingredient(
          amount: _parseNumber(r.amount.text) ?? 0,
          unit: r.unit,
          name: r.name.text.trim(),
        ),
  ];

  void dispose() {
    text.dispose();
    for (final p in phases) {
      p.dispose();
    }
    for (final r in ingredients) {
      r.dispose();
    }
  }
}

double? _parseNumber(String s) =>
    double.tryParse(s.trim().replaceAll(',', '.'));

class _RecipeEditorPageState extends ConsumerState<RecipeEditorPage> {
  late final Recipe _original;
  final _title = TextEditingController();
  final _tags = TextEditingController();
  int _servings = 4;
  final _steps = <_StepRow>[];

  Uint8List? _newPhoto; // gewählt, noch nicht hochgeladen
  String?
  _uploadedSha; // schon hochgeladen (bei erneutem Speichern nicht noch mal)
  bool _removePhoto = false;
  bool _saving = false;
  bool _titleError = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.id == null
        ? null
        : ref.read(recipeProvider(widget.id!));
    _original =
        existing ??
        Recipe(
          id: newRecipeId(),
          rev: 0,
          updated: DateTime.now().toUtc(),
          title: '',
          servings: 4,
        );
    _title.text = _original.title;
    _tags.text = _original.tags.join(', ');
    _servings = _original.servings < 1 ? 1 : _original.servings;
    _steps.addAll(_original.steps.map(_StepRow.new));
    if (_steps.isEmpty) _steps.add(_StepRow());
  }

  @override
  void dispose() {
    _title.dispose();
    _tags.dispose();
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  /// Aktuelle Eingaben als Rezept; `null`, wenn ein Maschinenschritt unvollständig ist.
  Recipe? _build() {
    final steps = <RecipeStep>[];
    for (final s in _steps) {
      final text = s.text.text.trim();
      final ingredients = s.builtIngredients;
      StepMachine? machine;
      if (s.hasMachine) {
        // Nur Einzelwerte mit Phasen; gespeicherte Box-Programme wählt man im Editor nicht mehr.
        final phasen = [for (final p in s.phases) p.built];
        if (phasen.any((p) => p == null)) return null;
        // Die Brücke startet kein Programm, das mit „Motor aus ohne Wärme“ beginnt.
        final erste = phasen.first!;
        if (erste.speed == 0 && erste.temperature == 0) return null;
        machine = StepMachine.phasen([for (final p in phasen) p!]);
      }
      if (text.isEmpty && ingredients.isEmpty && machine == null) continue;
      steps.add(
        RecipeStep(
          text: text,
          photo: s.photo,
          ingredients: ingredients,
          tool: s.tool,
          machine: machine,
        ),
      );
    }
    return _original.copyWith(
      title: _title.text.trim(),
      servings: _servings,
      tags: [
        for (final t in _tags.text.split(','))
          if (t.trim().isNotEmpty) t.trim(),
      ],
      photo: _uploadedSha,
      clearPhoto: _removePhoto && _uploadedSha == null,
      steps: steps,
    );
  }

  bool get _changed {
    if (_newPhoto != null || _removePhoto) return true;
    final now = _build();
    if (now == null) return true;
    String key(Recipe r) => jsonEncode({...r.toJson(), 'updated': null});
    return key(now) != key(_original);
  }

  Future<void> _pickPhoto({required bool camera}) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final webp = await pickRecipePhoto(camera: camera);
      if (webp == null || !mounted) return;
      setState(() {
        _newPhoto = webp;
        _uploadedSha = null;
        _removePhoto = false;
      });
    } on PhotoTooBigException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.editorPhotoTooBig)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.editorPhotoFailed)));
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    if (_title.text.trim().isEmpty) {
      setState(() => _titleError = true);
      return;
    }
    var recipe = _build();
    if (recipe == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.editorMachineInvalid)),
      );
      return;
    }
    final library = ref.read(recipeLibraryProvider.notifier);
    setState(() => _saving = true);
    try {
      if (_newPhoto != null && _uploadedSha == null) {
        _uploadedSha = await library.uploadPhoto(_newPhoto!);
        recipe = recipe.copyWith(photo: _uploadedSha);
      }
      var result = await library.save(recipe);
      if (result is RecipeConflict) {
        final overwrite = await _askConflict(result);
        if (overwrite != true) {
          // Andere Fassung behalten: Bearbeitung verwerfen.
          await library.sync();
          router.go(result.deleted ? '/rezepte' : '/rezepte/${recipe.id}');
          return;
        }
        result = await library.save(recipe.copyWith(rev: result.currentRev));
      }
      if (result is RecipeWritten) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.editorSaved)));
        router.go('/rezepte/${recipe.id}');
      }
    } on BridgeException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.kind == BridgeErrorKind.rejected
                ? l10n.editorSaveRejected(e.code ?? '${e.statusCode}')
                : l10n.bridgeUnreachable,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _askConflict(RecipeConflict c) {
    final l10n = context.l10n;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.conflictTitle),
        content: Text(c.deleted ? l10n.conflictDeletedText : l10n.conflictText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.conflictKeepOther),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.conflictOverwrite),
          ),
        ],
      ),
    );
  }

  Future<void> _onPop(bool didPop, Object? _) async {
    if (didPop) return;
    final navigator = Navigator.of(context);
    if (!_changed) {
      navigator.pop();
      return;
    }
    final l10n = context.l10n;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editorDiscardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.editorKeepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.editorDiscard),
          ),
        ],
      ),
    );
    if (discard == true) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final caps = ref.watch(bridgeInfoProvider).value?.readyCaps;
    final basics = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          style: theme.textTheme.titleLarge,
          decoration: InputDecoration(
            labelText: l10n.editorTitle,
            errorText: _titleError ? l10n.editorTitleMissing : null,
          ),
          onChanged: (_) {
            if (_titleError) setState(() => _titleError = false);
          },
        ),
        const SizedBox(height: Tokens.m),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.editorServings,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton.filledTonal(
              tooltip: l10n.recipeLess,
              onPressed: _servings > 1
                  ? () => setState(() => _servings--)
                  : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '$_servings',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton.filledTonal(
              tooltip: l10n.recipeMore,
              onPressed: _servings < 99
                  ? () => setState(() => _servings++)
                  : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: Tokens.m),
        TextField(
          controller: _tags,
          decoration: InputDecoration(
            labelText: l10n.editorTags,
            hintText: l10n.editorTagsHint,
          ),
        ),
        const SizedBox(height: Tokens.l),
        Text(l10n.editorPhoto, style: theme.textTheme.titleMedium),
        const SizedBox(height: Tokens.s),
        _photoPreview(),
        const SizedBox(height: Tokens.s),
        Wrap(
          spacing: Tokens.s,
          runSpacing: Tokens.s,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickPhoto(camera: true),
              icon: const Icon(Icons.photo_camera_rounded),
              label: Text(l10n.editorCamera),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickPhoto(camera: false),
              icon: const Icon(Icons.photo_library_rounded),
              label: Text(l10n.editorGallery),
            ),
            if (_newPhoto != null || (_original.photo != null && !_removePhoto))
              TextButton.icon(
                onPressed: () => setState(() {
                  _newPhoto = null;
                  _uploadedSha = null;
                  _removePhoto = true;
                }),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(l10n.editorPhotoRemove),
              ),
          ],
        ),
        const SizedBox(height: Tokens.l),
        Text(l10n.editorIngredients, style: theme.textTheme.headlineSmall),
        Text(
          l10n.recipeIngredientsAuto,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Tokens.s),
        for (final i in sumIngredients([
          for (final st in _steps) ...st.builtIngredients,
        ]))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(ingredientText(i, 1), style: theme.textTheme.bodyLarge),
          ),
      ],
    );

    final steps = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.editorSteps, style: theme.textTheme.headlineSmall),
        const SizedBox(height: Tokens.s),
        for (final (i, row) in _steps.indexed)
          _StepEditor(
            key: ObjectKey(row),
            number: i + 1,
            row: row,
            caps: caps,
            onChanged: () => setState(() {}),
            onRemove: () => setState(() => _steps.removeAt(i).dispose()),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _steps.add(_StepRow())),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.editorAddStep),
          ),
        ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.id == null ? l10n.editorNewTitle : l10n.editorEditTitle,
          ),
          actions: const [HilfeKnopf(hilfeEditor)],
        ),
        body: AdaptivePage(
          primary: basics,
          secondary: steps,
          bottom: BigButton(
            label: l10n.editorSave,
            icon: Icons.check_rounded,
            busy: _saving,
            onPressed: _save,
          ),
        ),
      ),
    );
  }

  Widget _photoPreview() {
    final Widget image;
    if (_newPhoto != null) {
      image = AspectRatio(
        aspectRatio: 16 / 10,
        child: Image.memory(_newPhoto!, fit: BoxFit.cover),
      );
    } else if (_original.photo != null && !_removePhoto) {
      image = RecipeImage(recipe: _original, aspectRatio: 16 / 10);
    } else {
      image = AspectRatio(
        aspectRatio: 16 / 10,
        child: const RecipeIllustration(),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radius),
      child: image,
    );
  }
}

class _IngredientEditor extends StatelessWidget {
  const _IngredientEditor({
    super.key,
    required this.row,
    required this.onRemove,
    this.onChanged,
  });

  final _IngredientRow row;
  final VoidCallback onRemove;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: TextField(
              controller: row.amount,
              onChanged: (_) => onChanged?.call(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
              ],
              decoration: InputDecoration(labelText: l10n.editorAmount),
            ),
          ),
          const SizedBox(width: Tokens.s),
          SizedBox(
            width: 104,
            child: DropdownButtonFormField<String>(
              initialValue: row.unit,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.editorUnit),
              items: [
                for (final u in {...recipeUnits, row.unit})
                  DropdownMenuItem(
                    value: u,
                    child: Text(u.isEmpty ? l10n.editorUnitNone : u),
                  ),
              ],
              onChanged: (u) {
                if (u == null) return;
                row.unit = u;
                onChanged?.call();
              },
            ),
          ),
          const SizedBox(width: Tokens.s),
          Expanded(
            child: TextField(
              controller: row.name,
              onChanged: (_) => onChanged?.call(),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.editorIngredientName),
            ),
          ),
          IconButton(
            tooltip: l10n.editorRemove,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _StepEditor extends StatelessWidget {
  const _StepEditor({
    super.key,
    required this.number,
    required this.row,
    required this.caps,
    required this.onChanged,
    required this.onRemove,
  });

  final int number;
  final _StepRow row;
  final ApplianceCaps? caps;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.m),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.editorStepNumber(number),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.editorRemove,
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              TextField(
                controller: row.text,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.editorStepText),
              ),
              const SizedBox(height: Tokens.s),
              Text(
                l10n.editorStepIngredients,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: Tokens.s),
              for (final (i, ing) in row.ingredients.indexed)
                _IngredientEditor(
                  key: ObjectKey(ing),
                  row: ing,
                  onChanged: onChanged,
                  onRemove: () {
                    row.ingredients.removeAt(i).dispose();
                    onChanged();
                  },
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    row.ingredients.add(_IngredientRow());
                    onChanged();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.editorAddIngredient),
                ),
              ),
              const SizedBox(height: Tokens.s),
              DropdownButtonFormField<Werkzeug?>(
                isExpanded: true,
                initialValue: row.tool,
                decoration: InputDecoration(labelText: l10n.editorTool),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.toolNone)),
                  for (final w in Werkzeug.values)
                    DropdownMenuItem(
                      value: w,
                      child: Row(
                        children: [
                          WerkzeugBild(w, size: 28),
                          const SizedBox(width: Tokens.s),
                          Flexible(
                            child: Text(
                              werkzeugName(l10n, w),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (w) {
                  row.tool = w;
                  onChanged();
                },
              ),
              const SizedBox(height: Tokens.s),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.blender_rounded),
                title: Text(l10n.editorStepKindMachine),
                value: row.hasMachine,
                onChanged: (on) {
                  row.hasMachine = on;
                  onChanged();
                },
              ),
              if (row.hasMachine) ..._machine(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _machine(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return [
      const SizedBox(height: Tokens.s),
      ...[
        for (final (i, phase) in row.phases.indexed) ...[
          if (i > 0) ...[
            const SizedBox(height: Tokens.m),
            Row(
              children: [
                const Icon(Icons.subdirectory_arrow_right_rounded),
                const SizedBox(width: Tokens.s),
                Expanded(
                  child: Text(
                    l10n.editorPhaseNumber(i + 1),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: l10n.editorPhaseRemove,
                  onPressed: () {
                    row.phases.removeAt(i).dispose();
                    onChanged();
                  },
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
              ],
            ),
          ],
          _PhaseEditor(
            key: ObjectKey(phase),
            phase: phase,
            caps: caps,
            onChanged: onChanged,
          ),
        ],
        if (_ersteOhneMotor(row.phases.first)) ...[
          const SizedBox(height: Tokens.s),
          Text(
            l10n.editorPhaseFirstOff,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (row.phases.length < maschinenPhasenMax)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                // Neue Phase übernimmt die Werte der letzten – meist ändert sich nur Stufe/Zeit.
                row.phases.add(_PhaseRow(row.phases.last.built));
                onChanged();
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.editorPhaseAdd),
            ),
          ),
      ],
    ];
  }
}

/// Erste Phase „Motor aus ohne Wärme“? Nimmt die Brücke nicht an (`first_step`).
bool _ersteOhneMotor(_PhaseRow p) =>
    p.speed == 0 && (int.tryParse(p.temperature.text.trim()) ?? 0) == 0;

/// Regler einer Phase: Temperatur, Zeit, Stufe (wie bisher für den ganzen Schritt).
class _PhaseEditor extends StatelessWidget {
  const _PhaseEditor({
    super.key,
    required this.phase,
    required this.caps,
    required this.onChanged,
  });

  final _PhaseRow phase;
  final ApplianceCaps? caps;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: phase.temperature,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => onChanged(),
                decoration: InputDecoration(
                  labelText: l10n.dialTemperature,
                  helperText: l10n.editorTempHint,
                ),
              ),
            ),
            const SizedBox(width: Tokens.s),
            Expanded(
              child: TextField(
                controller: phase.time,
                keyboardType: TextInputType.number,
                inputFormatters: [DurationDigitsFormatter()],
                decoration: InputDecoration(
                  labelText: l10n.dialTime,
                  helperText: l10n.editorTimeHint,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Tokens.s),
        if (caps != null)
          // Derselbe Regler wie im Maschinen-Tab: Rührintervall | Aus | min 1 … 6 max.
          SpeedSlider(
            label: l10n.dialSpeed,
            options: caps!.speeds,
            selected: phase.speed ?? 0,
            framed: false,
            onChanged: (v) {
              phase.speed = v;
              onChanged();
            },
          )
        else
          TextFormField(
            initialValue: phase.speed?.toString() ?? '',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l10n.dialSpeed),
            onChanged: (v) {
              phase.speed = int.tryParse(v);
              onChanged();
            },
          ),
      ],
    );
  }
}
