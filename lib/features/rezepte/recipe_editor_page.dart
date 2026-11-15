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
import '../../ui/input.dart';
import '../../ui/layout.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import '../../ui/widgets/speed_slider.dart';
import '../kochen/programs.dart';
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
      unit = TextEditingController(text: i?.unit ?? 'g'),
      name = TextEditingController(text: i?.name ?? '');

  final TextEditingController amount, unit, name;

  void dispose() {
    amount.dispose();
    unit.dispose();
    name.dispose();
  }
}

enum _StepKind { text, weigh, machine }

class _StepRow {
  _StepRow([RecipeStep? s])
    : text = TextEditingController(text: s?.text ?? ''),
      photo = s?.photo,
      kind = s?.weigh != null
          ? _StepKind.weigh
          : s?.machine != null
          ? _StepKind.machine
          : _StepKind.text,
      weighTarget = TextEditingController(
        text: s?.weigh == null ? '' : formatAmount(s!.weigh!.target),
      ),
      weighUnit = TextEditingController(text: s?.weigh?.unit ?? 'g'),
      useProgram = s?.machine?.programId != null,
      programId = s?.machine?.programId,
      temperature = TextEditingController(
        text: '${s?.machine?.settings?.temperature ?? 0}',
      ),
      time = TextEditingController(
        text: s?.machine?.settings == null
            ? ''
            : formatDuration(s!.machine!.settings!.time),
      ),
      speed = s?.machine?.settings?.speed;

  final TextEditingController text, weighTarget, weighUnit, temperature, time;
  final String?
  photo; // Schrittfotos bleiben erhalten, werden hier (noch) nicht bearbeitet
  _StepKind kind;
  bool useProgram;
  String? programId;
  int? speed;

  void dispose() {
    for (final c in [text, weighTarget, weighUnit, temperature, time]) {
      c.dispose();
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
  final _ingredients = <_IngredientRow>[];
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
    _ingredients.addAll(_original.ingredients.map(_IngredientRow.new));
    _steps.addAll(_original.steps.map(_StepRow.new));
    if (_ingredients.isEmpty) _ingredients.add(_IngredientRow());
    if (_steps.isEmpty) _steps.add(_StepRow());
  }

  @override
  void dispose() {
    _title.dispose();
    _tags.dispose();
    for (final r in _ingredients) {
      r.dispose();
    }
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
      switch (s.kind) {
        case _StepKind.text:
          if (text.isEmpty) continue;
          steps.add(RecipeStep(text: text, photo: s.photo));
        case _StepKind.weigh:
          final target = _parseNumber(s.weighTarget.text);
          steps.add(
            RecipeStep(
              text: text,
              photo: s.photo,
              weigh: target == null || target <= 0
                  ? null
                  : WeighTarget(
                      target: target,
                      unit: s.weighUnit.text.trim().isEmpty
                          ? 'g'
                          : s.weighUnit.text.trim(),
                    ),
            ),
          );
        case _StepKind.machine:
          StepMachine machine;
          if (s.useProgram) {
            if (s.programId == null) return null;
            machine = StepMachine.program(s.programId!);
          } else {
            final time = parseDurationText(s.time.text);
            final temp = int.tryParse(s.temperature.text.trim()) ?? 0;
            if (time == null || time <= 0 || s.speed == null || temp < 0) {
              return null;
            }
            machine = StepMachine.settings(
              MachineSettings(temperature: temp, time: time, speed: s.speed!),
            );
          }
          steps.add(RecipeStep(text: text, photo: s.photo, machine: machine));
      }
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
      ingredients: [
        for (final r in _ingredients)
          if (r.name.text.trim().isNotEmpty)
            Ingredient(
              amount: _parseNumber(r.amount.text) ?? 0,
              unit: r.unit.text.trim(),
              name: r.name.text.trim(),
            ),
      ],
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
    final programs = ref.watch(bridgeProgramsProvider).value ?? const [];

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
        const SizedBox(height: Tokens.s),
        for (final (i, row) in _ingredients.indexed)
          _IngredientEditor(
            key: ObjectKey(row),
            row: row,
            onRemove: () => setState(() {
              _ingredients.removeAt(i).dispose();
            }),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _ingredients.add(_IngredientRow())),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.editorAddIngredient),
          ),
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
            programs: programs,
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
        child: RecipeIllustration(title: _title.text),
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
  });

  final _IngredientRow row;
  final VoidCallback onRemove;

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
            width: 80,
            child: TextField(
              controller: row.unit,
              decoration: InputDecoration(labelText: l10n.editorUnit),
            ),
          ),
          const SizedBox(width: Tokens.s),
          Expanded(
            child: TextField(
              controller: row.name,
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
    required this.programs,
    required this.onChanged,
    required this.onRemove,
  });

  final int number;
  final _StepRow row;
  final ApplianceCaps? caps;
  final List<Program> programs;
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
              SegmentedButton<_StepKind>(
                segments: [
                  ButtonSegment(
                    value: _StepKind.text,
                    label: Text(l10n.editorStepKindText),
                  ),
                  ButtonSegment(
                    value: _StepKind.weigh,
                    icon: const Icon(Icons.scale_rounded),
                    label: Text(l10n.editorStepKindWeigh),
                  ),
                  ButtonSegment(
                    value: _StepKind.machine,
                    icon: const Icon(Icons.blender_rounded),
                    label: Text(l10n.editorStepKindMachine),
                  ),
                ],
                selected: {row.kind},
                onSelectionChanged: (v) {
                  row.kind = v.first;
                  onChanged();
                },
              ),
              if (row.kind == _StepKind.weigh) ...[
                const SizedBox(height: Tokens.s),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: row.weighTarget,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.editorWeighTarget,
                        ),
                      ),
                    ),
                    const SizedBox(width: Tokens.s),
                    SizedBox(
                      width: 96,
                      child: TextField(
                        controller: row.weighUnit,
                        decoration: InputDecoration(labelText: l10n.editorUnit),
                      ),
                    ),
                  ],
                ),
              ],
              if (row.kind == _StepKind.machine) ..._machine(context),
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
      SegmentedButton<bool>(
        segments: [
          ButtonSegment(value: false, label: Text(l10n.editorMachineValues)),
          ButtonSegment(value: true, label: Text(l10n.editorMachineProgram)),
        ],
        selected: {row.useProgram},
        onSelectionChanged: (v) {
          row.useProgram = v.first;
          onChanged();
        },
      ),
      const SizedBox(height: Tokens.s),
      if (row.useProgram)
        if (programs.isEmpty && row.programId == null)
          Text(l10n.editorProgramNone, style: theme.textTheme.bodyMedium)
        else
          DropdownButtonFormField<String>(
            initialValue: row.programId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.editorProgramChoose),
            items: [
              for (final p in programs)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
              if (row.programId != null &&
                  !programs.any((p) => p.id == row.programId))
                DropdownMenuItem(
                  value: row.programId,
                  child: Text(row.programId!),
                ),
            ],
            onChanged: (v) {
              row.programId = v;
              onChanged();
            },
          )
      else ...[
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: row.temperature,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.dialTemperature,
                  helperText: l10n.editorTempHint,
                ),
              ),
            ),
            const SizedBox(width: Tokens.s),
            Expanded(
              child: TextField(
                controller: row.time,
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
          DropdownButtonFormField<int>(
            initialValue: caps!.speedOption(row.speed ?? -1) == null
                ? null
                : row.speed,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.dialSpeed),
            items: [
              for (final o in caps!.speeds)
                DropdownMenuItem(
                  value: o.v,
                  child: Text(speedText(context, caps, o.v)),
                ),
            ],
            onChanged: (v) {
              row.speed = v;
              onChanged();
            },
          )
        else
          TextFormField(
            initialValue: row.speed?.toString() ?? '',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l10n.dialSpeed),
            onChanged: (v) => row.speed = int.tryParse(v),
          ),
      ],
    ];
  }
}
