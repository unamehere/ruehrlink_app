import 'json.dart';
import 'machine_settings.dart';

/// Multi-Programm (`GET /api/v1/programs`): mehrere Schritte, ein Knopfdreh.
/// Die Abfolge läuft auf der Brücke, nie im Handy.
class Program {
  const Program({
    required this.id,
    required this.name,
    required this.steps,
    this.scaleBy,
  });

  final String id;
  final String name;
  final List<ProgramStep> steps;
  final ScaleBy? scaleBy;

  /// Gesamtdauer aller Schritte in Sekunden.
  int get totalTime => steps.fold(0, (sum, s) => sum + s.settings.time);

  factory Program.fromJson(Json json) => Program(
    id: readString(json['id']),
    name: readString(json['name']),
    steps: readList(json['steps'], ProgramStep.fromJson),
    scaleBy: json['scaleBy'] is Map
        ? ScaleBy.fromJson(readMap(json['scaleBy']))
        : null,
  );

  Json toJson() => {
    'id': id,
    'name': name,
    if (scaleBy != null) 'scaleBy': scaleBy!.toJson(),
    'steps': [for (final s in steps) s.toJson()],
  };
}

class ProgramStep {
  const ProgramStep({required this.settings, this.label = ''});

  final MachineSettings settings;
  final String label;

  factory ProgramStep.fromJson(Json json) => ProgramStep(
    settings: MachineSettings.fromJson(json),
    label: readString(json['label']),
  );

  Json toJson() => {...settings.toJson(), 'label': label};
}

/// Programm skaliert mit der Menge einer Zutat (später, gemessen per Waage).
class ScaleBy {
  const ScaleBy({required this.ingredient, required this.baseGrams});

  final String ingredient;
  final int baseGrams;

  factory ScaleBy.fromJson(Json json) => ScaleBy(
    ingredient: readString(json['ingredient']),
    baseGrams: readInt(json['baseGrams']),
  );

  Json toJson() => {'ingredient': ingredient, 'baseGrams': baseGrams};
}
