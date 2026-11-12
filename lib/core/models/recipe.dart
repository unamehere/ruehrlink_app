import 'json.dart';
import 'machine_settings.dart';

/// Rezept, wie es auf der Brücke liegt (`/api/v1/recipes/{id}`).
class Recipe {
  const Recipe({
    required this.id,
    required this.rev,
    required this.updated,
    required this.title,
    required this.servings,
    this.photo,
    this.tags = const [],
    this.ingredients = const [],
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
  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;

  factory Recipe.fromJson(Json json) => Recipe(
    id: readString(json['id']),
    rev: readInt(json['rev']),
    updated:
        DateTime.tryParse(readString(json['updated'])) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    title: readString(json['title']),
    servings: readInt(json['servings'], 1),
    photo: json['photo'] as String?,
    tags: json['tags'] is List
        ? List.unmodifiable((json['tags'] as List).whereType<String>())
        : const [],
    ingredients: readList(json['ingredients'], Ingredient.fromJson),
    steps: readList(json['steps'], RecipeStep.fromJson),
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

  final double amount;
  final String unit;
  final String name;

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

class RecipeStep {
  const RecipeStep({required this.text, this.photo, this.weigh, this.machine});

  final String text;
  final String? photo;
  final WeighTarget? weigh;
  final StepMachine? machine;

  factory RecipeStep.fromJson(Json json) => RecipeStep(
    text: readString(json['text']),
    photo: json['photo'] as String?,
    weigh: json['weigh'] is Map
        ? WeighTarget.fromJson(readMap(json['weigh']))
        : null,
    machine: json['machine'] is Map
        ? StepMachine.fromJson(readMap(json['machine']))
        : null,
  );

  Json toJson() => {
    'text': text,
    if (photo != null) 'photo': photo,
    if (weigh != null) 'weigh': weigh!.toJson(),
    if (machine != null) 'machine': machine!.toJson(),
  };
}

class WeighTarget {
  const WeighTarget({required this.target, required this.unit});

  final double target;
  final String unit;

  factory WeighTarget.fromJson(Json json) => WeighTarget(
    target: readDouble(json['target']),
    unit: readString(json['unit'], 'g'),
  );

  Json toJson() => {
    'target': target == target.roundToDouble() ? target.toInt() : target,
    'unit': unit,
  };
}

/// Maschinenschritt im Rezept: entweder ein Multi-Programm ([programId])
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
    changed: readList(json['changed'], Recipe.fromJson),
    deleted: json['deleted'] is List
        ? List.unmodifiable((json['deleted'] as List).whereType<String>())
        : const [],
  );
}
