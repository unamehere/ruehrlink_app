import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../rezepte/recipe_library.dart';
import 'assistent.dart';
import 'katalog.dart';

/// „Als Rezept speichern“: Ergebnis eines Assistenten → normales [Recipe], danach im Editor frei
/// änderbar (Sprint-Plan 23.11., Abschnitt 4).
///
/// Aufbau:
/// 1. „Zutaten in die Schüssel geben“ mit allen Zutaten (Gramm-Zutaten wiegt der Kochmodus
///    nacheinander ab) und dem Werkzeug des Assistenten, dazu die Tipps (ohne Sicherheitshinweise –
///    die zeigt der Kochmodus selbst, abschaltbar).
/// 2. Die Programmschritte mit denselben Maschinenwerten (Stufe aus `caps`); direkt
///    aufeinanderfolgende werden Phasen eines Rezeptschritts (ein Start am Gerät wie im
///    Assistenten). Ruhephasen ohne Motor und ohne Hitze werden zum Textschritt: Die Brücke startet
///    kein Programm, das mit einem solchen Schritt beginnt (`first_step`), und der Kochmodus
///    schickt jeden Rezeptschritt einzeln.
///
/// `null`, wenn der Plan nicht zu [caps] passt (wie [programmAusPlan]).
Recipe? rezeptAusPlan(
  AssistentPlan plan, {
  required String id,
  required String titel,
  required int portionen,
  required ApplianceCaps caps,
  required AppLocalizations l10n,
  required DateTime jetzt,
}) {
  final programm = programmAusPlan(plan, name: titel, caps: caps, l10n: l10n);
  if (programm == null) return null;

  final tipps = [
    for (final h in plan.hinweise)
      // „Knopf nach der Pause“ gilt nur im durchlaufenden Programm, nicht im Kochmodus.
      if (!h.sicherheit && h != Hinweis.knopfNachRuhe) hinweisText(l10n, h),
  ];
  final schritte = <RecipeStep>[
    RecipeStep(
      text: [l10n.asSaveStepIngredients, ...tipps].join(' '),
      tool: plan.werkzeug,
      ingredients: [for (final z in plan.zutaten) zutatAlsIngredient(l10n, z)],
    ),
  ];
  // Maschinenschritte, die direkt aufeinander folgen, werden Phasen eines Schritts – so läuft
  // es wie im Assistenten mit einem Start durch (z. B. Unterrühren → Kneten).
  var block = <ProgramStep>[];
  void blockAbschliessen() {
    if (block.isEmpty) return;
    schritte.add(
      RecipeStep(
        // Gleiche Beschriftung wie im Programm des Assistenten, Phasen mit „, dann“.
        text: [
          for (final (n, p) in block.indexed)
            n == 0 ? p.label : l10n.asSaveStepThen(p.label),
        ].join(', '),
        machine: StepMachine.phasen([for (final p in block) p.settings]),
      ),
    );
    block = [];
  }

  for (final (i, s) in plan.schritte.indexed) {
    final label = schrittLabel(l10n, s.art);
    if (s.ruhe && s.temperatur == 0) {
      blockAbschliessen();
      schritte.add(
        RecipeStep(text: l10n.asSaveStepRest(label, (s.zeitS / 60).ceil())),
      );
      continue;
    }
    if (block.length >= maschinenPhasenMax) blockAbschliessen();
    block.add(programm.steps[i]);
  }
  blockAbschliessen();

  return Recipe(
    id: id,
    rev: 0,
    updated: jetzt.toUtc(),
    title: fitUtf8(titel.trim(), rezeptTitelMaxBytes),
    servings: portionen.clamp(1, 1000),
    steps: schritte,
  );
}

/// Titel: 1–200 Zeichen (`ruehrlink_esp/docs/api.md` → „Rezept“); in Bytes gezählt ist man sicher.
const rezeptTitelMaxBytes = 200;

/// Zutat des Assistenten als Rezeptzutat: g/ml wie gerechnet, Stück ohne Einheit („4 Eiweiß“),
/// Prise als „1 Prise Salz“.
Ingredient zutatAlsIngredient(AppLocalizations l10n, ZutatMenge z) =>
    Ingredient(
      amount: z.menge,
      unit: switch (z.einheit) {
        Einheit.g => 'g',
        Einheit.ml => 'ml',
        Einheit.stueck => '',
        Einheit.prise => 'Prise',
      },
      name: zutatName(l10n, z),
    );
