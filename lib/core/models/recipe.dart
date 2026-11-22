import 'json.dart';
import 'machine_settings.dart';
import 'werkzeug.dart';

/// Rezept, wie es auf der Brücke liegt (`/api/v1/recipes/{id}`).
///
/// Zutaten gehören zu den Schritten ([RecipeStep.ingredients]); die Gesamtliste [ingredients]
/// wird daraus zusammengezählt. Sie wird trotzdem mitgespeichert (`ingredients` oben im JSON),
/// damit z. B. eine Einkaufsliste auf der Brücke sie lesen kann, ohne Schritte zu durchsuchen.
class Recipe {
  const Recipe({
    required this.id,
    required this.rev,
    required this.updated,
    required this.title,
    required this.servings,
    this.photo,
    this.tags = const [],
    this.steps = const [],
  });

  final String id;

  /// Revision – für `If-Match` beim Speichern und für den Abgleich.
  final int rev;
  final DateTime updated;
  final String title;
  final int servings;

  /// SHA-256 des Fotos (`/api/v1/media/{sha256}`).
  final String? photo;
  final List<String> tags;
  final List<RecipeStep> steps;

  /// Alle Zutaten des Rezepts, gleiche Zutat (Name + Einheit) zusammengezählt.
  List<Ingredient> get ingredients =>
      sumIngredients([for (final s in steps) ...s.ingredients]);

  factory Recipe.fromJson(Json json) {
    final rawSteps = json['steps'] is List ? json['steps'] as List : const [];
    final perStep = rawSteps.any((s) => s is Map && s['ingredients'] is List);
    var steps = readList(json['steps'], RecipeStep.fromJson);
    if (!perStep) {
      // Altes Format (bis App 0.3.2): Zutatenliste oben, Schritte nur mit `weigh`.
      steps = migrateLegacySteps(
        readList(json['ingredients'], Ingredient.fromJson),
        steps,
        [
          for (final s in rawSteps)
            s is Map && s['weigh'] is Map
                ? (
                    readDouble((s['weigh'] as Map)['target']),
                    readString((s['weigh'] as Map)['unit'], 'g'),
                  )
                : null,
        ],
      );
    }
    return Recipe(
      id: readString(json['id']),
      rev: readInt(json['rev']),
      updated:
          DateTime.tryParse(readString(json['updated'])) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      title: readString(json['title']),
      servings: readInt(json['servings'], 1),
      photo: json['photo'] is String ? json['photo'] as String : null,
      tags: json['tags'] is List
          ? List.unmodifiable((json['tags'] as List).whereType<String>())
          : const [],
      steps: steps,
    );
  }

  Recipe copyWith({
    int? rev,
    DateTime? updated,
    String? title,
    int? servings,
    String? photo,
    bool clearPhoto = false,
    List<String>? tags,
    List<RecipeStep>? steps,
  }) => Recipe(
    id: id,
    rev: rev ?? this.rev,
    updated: updated ?? this.updated,
    title: title ?? this.title,
    servings: servings ?? this.servings,
    photo: clearPhoto ? null : (photo ?? this.photo),
    tags: tags ?? this.tags,
    steps: steps ?? this.steps,
  );

  Json toJson() => {
    'id': id,
    'rev': rev,
    'updated': updated.toUtc().toIso8601String(),
    'title': title,
    'servings': servings,
    'photo': photo,
    'tags': tags,
    'ingredients': [for (final i in ingredients) i.toJson()],
    'steps': [for (final s in steps) s.toJson()],
  };
}

class Ingredient {
  const Ingredient({
    required this.amount,
    required this.unit,
    required this.name,
  });

  /// 0 = ohne Menge (z. B. „Prise Salz“).
  final double amount;
  final String unit;
  final String name;

  /// Lässt sich mit der Waage abwiegen? Dann die Menge in Gramm, sonst `null`.
  /// Flüssigkeiten in ml/l werden über die Dichte umgerechnet ([liquidDensity]).
  double? get grams => amount <= 0
      ? null
      : switch (unit.trim().toLowerCase()) {
          'g' => amount,
          'kg' => amount * 1000,
          'ml' => amount * liquidDensity(name),
          'l' => amount * 1000 * liquidDensity(name),
          _ => null,
        };

  /// Mengenangabe in ml/l (die Waage zeigt dann „≈ … g“)?
  bool get isVolume => switch (unit.trim().toLowerCase()) {
    'ml' || 'l' => true,
    _ => false,
  };

  Ingredient scaled(double factor) =>
      Ingredient(amount: amount * factor, unit: unit, name: name);

  factory Ingredient.fromJson(Json json) => Ingredient(
    amount: readDouble(json['amount']),
    unit: readString(json['unit']),
    name: readString(json['name']),
  );

  Json toJson() => {
    // Ganze Zahlen ohne „.0“ schreiben, wie in der API.
    'amount': amount == amount.roundToDouble() ? amount.toInt() : amount,
    'unit': unit,
    'name': name,
  };
}

/// Einheiten zur Auswahl im Editor (in dieser Reihenfolge). `''` = ohne Einheit („2 Eier“).
/// Abwiegen lassen sich g, kg, ml und l.
const recipeUnits = [
  'g',
  'kg',
  'ml',
  'l',
  'EL',
  'TL',
  'Prise',
  'Msp.',
  'Pck.',
  'Stück',
  '',
];

/// Dichte in g/ml für das Abwiegen von Flüssigkeiten; grob genug für die Toleranz der Waage
/// (3 %). Unbekannt → wie Wasser.
double liquidDensity(String name) {
  final n = name.toLowerCase();
  // „Öl“, „Rapsöl“, „Olivenöl extra“ – aber nicht „Kölsch“
  if (n
      .split(RegExp(r'[\s,()/-]+'))
      .any((w) => w.endsWith('öl') || w.endsWith('oel'))) {
    return 0.92;
  }
  if (n.contains('honig')) return 1.4;
  if (n.contains('sirup')) return 1.33;
  if (n.contains('milch') || n.contains('buttermilch')) return 1.03;
  return 1.0;
}

/// Gleiche Zutaten (Name und Einheit, Groß-/Kleinschreibung egal) zusammenzählen; Reihenfolge
/// nach erstem Auftreten.
List<Ingredient> sumIngredients(Iterable<Ingredient> all) {
  final order = <String>[];
  final sums = <String, Ingredient>{};
  for (final i in all) {
    if (i.name.trim().isEmpty) continue;
    final key = '${i.name.trim().toLowerCase()}|${i.unit.trim().toLowerCase()}';
    final prev = sums[key];
    if (prev == null) {
      order.add(key);
      sums[key] = i;
    } else {
      sums[key] = Ingredient(
        amount: prev.amount + i.amount,
        unit: prev.unit,
        name: prev.name,
      );
    }
  }
  return List.unmodifiable([for (final k in order) sums[k]!]);
}

/// Altes Format → Zutaten pro Schritt. Ein `weigh`-Schritt bekommt die passende Zutat aus der
/// Liste (gleiche Menge und Einheit), sonst eine namenlose mit dem Schritttext. Was übrig bleibt,
/// kommt in den ersten Schritt – so geht keine Zutat verloren.
List<RecipeStep> migrateLegacySteps(
  List<Ingredient> legacy,
  List<RecipeStep> steps,
  List<(double, String)?> weighs,
) {
  final rest = [...legacy];
  final out = <RecipeStep>[];
  for (var n = 0; n < steps.length; n++) {
    final s = steps[n];
    final w = n < weighs.length ? weighs[n] : null;
    if (w == null) {
      out.add(s);
      continue;
    }
    final (target, unit) = w;
    final i = rest.indexWhere(
      (x) =>
          x.amount == target &&
          x.unit.trim().toLowerCase() == unit.trim().toLowerCase(),
    );
    final ing = i >= 0
        ? rest.removeAt(i)
        : Ingredient(amount: target, unit: unit, name: s.text);
    out.add(s.copyWith(ingredients: [ing]));
  }
  if (rest.isNotEmpty) {
    if (out.isEmpty) {
      out.add(RecipeStep(text: '', ingredients: rest));
    } else {
      out[0] = out[0].copyWith(ingredients: [...rest, ...out[0].ingredients]);
    }
  }
  return out;
}

class RecipeStep {
  const RecipeStep({
    required this.text,
    this.photo,
    this.ingredients = const [],
    this.tool,
    this.machine,
  });

  final String text;
  final String? photo;

  /// Was in diesem Schritt dazukommt. Gramm-Zutaten wiegt der Kochmodus nacheinander ab.
  final List<Ingredient> ingredients;

  /// Werkzeug für diesen Schritt (`null` = wie vorher / egal).
  final Werkzeug? tool;
  final StepMachine? machine;

  RecipeStep copyWith({
    String? text,
    List<Ingredient>? ingredients,
    Werkzeug? tool,
    bool clearTool = false,
  }) => RecipeStep(
    text: text ?? this.text,
    photo: photo,
    ingredients: ingredients ?? this.ingredients,
    tool: clearTool ? null : (tool ?? this.tool),
    machine: machine,
  );

  factory RecipeStep.fromJson(Json json) => RecipeStep(
    text: readString(json['text']),
    photo: json['photo'] is String ? json['photo'] as String : null,
    ingredients: readList(json['ingredients'], Ingredient.fromJson),
    tool: Werkzeug.fromJson(json['tool']),
    machine: json['machine'] is Map
        ? StepMachine.fromJson(readMap(json['machine']))
        : null,
  );

  Json toJson() => {
    'text': text,
    if (photo != null) 'photo': photo,
    if (ingredients.isNotEmpty)
      'ingredients': [for (final i in ingredients) i.toJson()],
    if (tool != null) 'tool': tool!.name,
    if (machine != null) 'machine': machine!.toJson(),
  };
}

/// Maschinenschritt im Rezept: entweder ein Programm ([programId])
/// oder direkte Einzelwerte ([settings]).
class StepMachine {
  const StepMachine.program(String this.programId) : settings = null;
  const StepMachine.settings(MachineSettings this.settings) : programId = null;

  final String? programId;
  final MachineSettings? settings;

  factory StepMachine.fromJson(Json json) => json['programId'] is String
      ? StepMachine.program(json['programId'] as String)
      : StepMachine.settings(MachineSettings.fromJson(json));

  Json toJson() =>
      programId != null ? {'programId': programId} : settings!.toJson();
}

/// Ergebnis von `PUT`/`DELETE /api/v1/recipes/{id}` mit `If-Match`.
sealed class RecipeWriteResult {
  const RecipeWriteResult();
}

/// Gespeichert bzw. gelöscht; [rev] ist die neue Revision.
class RecipeWritten extends RecipeWriteResult {
  const RecipeWritten({required this.rev, this.updated});
  final int rev;
  final DateTime? updated;
}

/// Jemand anderes war schneller (`412`): die Brücke hat inzwischen Revision [currentRev]
/// (0 = gibt es nicht mehr) bzw. das Rezept wurde [deleted].
class RecipeConflict extends RecipeWriteResult {
  const RecipeConflict({required this.currentRev, required this.deleted});
  final int currentRev;
  final bool deleted;
}

Recipe? _tryRecipe(Json json) {
  try {
    final r = Recipe.fromJson(json);
    return r.id.isEmpty ? null : r;
  } on Object {
    return null;
  }
}

/// Antwort von `GET /api/v1/recipes?since=<rev>`.
class RecipeChanges {
  const RecipeChanges({
    required this.rev,
    this.changed = const [],
    this.deleted = const [],
  });

  final int rev;
  final List<Recipe> changed;
  final List<String> deleted;

  factory RecipeChanges.fromJson(Json json) => RecipeChanges(
    rev: readInt(json['rev']),
    // Ein unlesbares Rezept darf den Abgleich der übrigen nicht verhindern (F20).
    changed: [
      for (final r in readList(json['changed'], (j) => j)) ?_tryRecipe(r),
    ],
    deleted: json['deleted'] is List
        ? List.unmodifiable((json['deleted'] as List).whereType<String>())
        : const [],
  );
}
