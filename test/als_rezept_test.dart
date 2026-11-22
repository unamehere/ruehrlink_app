// „Als Rezept speichern“: Assistent → Rezept (Sprint-Plan 23.11., Abschnitt 4).
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/core/api/fake_bridge_api.dart';
import 'package:ruehrlink/core/models/models.dart';
import 'package:ruehrlink/features/assistenten/als_rezept.dart';
import 'package:ruehrlink/features/assistenten/assistent.dart';
import 'package:ruehrlink/features/assistenten/katalog.dart';
import 'package:ruehrlink/features/assistenten/werte.dart';
import 'package:ruehrlink/features/rezepte/kochmodus_page.dart';
import 'package:ruehrlink/l10n/app_localizations.dart';

const caps = FakeBridgeApi.demoCaps;
final l10n = lookupAppLocalizations(const Locale('de'));
final jetzt = DateTime.utc(2026, 11, 22, 12);

Recipe rezept(Assistent a, Antworten x, {String? titel}) => rezeptAusPlan(
  a.plan(x),
  id: 'abc-123',
  titel: titel ?? a.rezeptTitel(l10n),
  portionen: a.portionen(x),
  caps: caps,
  l10n: l10n,
  jetzt: jetzt,
)!;

/// Vorschläge plus jede Option jeder Frage einzeln (wie im Programm-Test).
List<Antworten> alleAntworten(Assistent a) => [
  {},
  for (final f in a.fragen)
    for (final o in f.optionen(const {})) {f.id: o.wert},
];

void main() {
  test('jeder Assistent ergibt ein gültiges Rezept mit denselben Maschinenwerten', () {
    for (final a in alleAssistenten) {
      for (final x in alleAntworten(a)) {
        final plan = a.plan(x);
        final r = rezept(a, x);
        final why = '${a.id} $x';

        // Gültig wie für die Brücke (docs/api.md → „Rezept“), Hin- und Rückweg über JSON.
        expect(r.rev, 0, reason: why);
        expect(r.title, isNotEmpty, reason: why);
        expect(utf8.encode(r.title).length, lessThanOrEqualTo(200));
        expect(r.servings, inInclusiveRange(1, 1000), reason: why);
        for (final s in r.steps) {
          expect(s.ingredients.length, lessThanOrEqualTo(50));
        }
        final zurueck = Recipe.fromJson(
          jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>,
        );
        expect(jsonEncode(zurueck.toJson()), jsonEncode(r.toJson()));

        // Erster Schritt: alle Zutaten mit den gerechneten Mengen, Werkzeug des Assistenten.
        final erster = r.steps.first;
        expect(erster.tool, plan.werkzeug, reason: why);
        expect(erster.machine, isNull);
        expect(erster.ingredients.length, plan.zutaten.length, reason: why);
        for (final (i, z) in plan.zutaten.indexed) {
          expect(erster.ingredients[i].name, zutatName(l10n, z));
          expect(erster.ingredients[i].amount, z.menge);
        }

        // Danach je Programmschritt ein Rezeptschritt in derselben Reihenfolge.
        final programm = programmAusPlan(
          plan,
          name: r.title,
          caps: caps,
          l10n: l10n,
        )!;
        final rest = r.steps.skip(1).toList();
        expect(rest.length, plan.schritte.length, reason: why);
        for (final (i, s) in plan.schritte.indexed) {
          final schritt = rest[i];
          if (s.ruhe && s.temperatur == 0) {
            // Ruhephase ohne Motor/Hitze: Textschritt mit Dauer (Brücke: `first_step`).
            expect(schritt.machine, isNull, reason: why);
            expect(schritt.text, contains('${(s.zeitS / 60).ceil()} min'));
            continue;
          }
          // Kochmodus schickt genau die Werte, die der Assistent geschickt hätte.
          final gesendet = einzelschrittProgramm(r, schritt);
          expect(
            gesendet.steps.single.settings,
            programm.steps[i].settings,
            reason: '$why Schritt $i',
          );
          expect(gesendet.steps.single.label, programm.steps[i].label);
          expect(gesendet.steps.single.settings.temperature, s.temperatur);
          expect(gesendet.steps.single.settings.time, s.zeitS);
          expect(gesendet.steps.single.settings.speed, s.stufe.aufloesen(caps));
          // … und die Brücke würde es annehmen (wie FakeBridgeApi/sequencer.c).
          final v = gesendet.steps.single.settings;
          expect(caps.clamp(v), v);
          expect(v.speed != 0 || v.temperature != 0, isTrue);
          expect(
            v.temperature >= caps.hotTemp! && caps.tooFastWhenHot(v.speed),
            isFalse,
          );
        }
      }
    }
  });

  test('Pizza: Titel „Meine Pizza“, Portionen = Anzahl, Wasser wiegbar', () {
    const a = PizzaAssistent();
    final r = rezept(a, {'anzahl': 6});
    expect(r.title, 'Meine Pizza');
    expect(r.servings, 6);
    final wasser = r.steps.first.ingredients.firstWhere(
      (i) => i.name == 'Wasser',
    );
    expect(wasser.unit, 'g');
    expect(wasser.grams, wasser.amount);
    expect(r.ingredients, isNotEmpty); // Gesamtliste wird mitgespeichert
  });

  test('Dinkel: Ruhephase wird Textschritt, Kneten und Nachkneten bleiben Maschine', () {
    const a = TeigAssistent();
    final r = rezept(a, {'mehl': Mehl.dinkel630});
    expect(r.steps.map((s) => s.text), [
      startsWith('Zutaten in die Schüssel'),
      'Unterrühren',
      'Kneten',
      'Ruhen: 5 min warten, Motor aus.',
      'Nachkneten',
    ]);
    expect(r.steps.map((s) => s.machine != null), [
      false,
      true,
      true,
      false,
      true,
    ]);
    expect(r.steps.first.tool, Werkzeug.knethaken);
    // „Knopf nach der Pause“ passt nur zum durchlaufenden Programm
    expect(r.steps.first.text, isNot(contains('Pause')));
  });

  test('Eischnee: Stück ohne Einheit, Prise Salz, Tipp im ersten Schritt', () {
    const a = EischneeAssistent();
    final r = rezept(a, {'anzahl': 6});
    final z = r.steps.first.ingredients;
    expect(z[0].amount, 6);
    expect(z[0].unit, '');
    expect(z[0].grams, isNull); // wird nicht gewogen
    expect(z[1].unit, 'Prise');
    expect(r.steps.first.text, contains('fettfrei'));
    expect(r.steps.first.tool, Werkzeug.schneebesen);
  });

  test(
    'Schokolade: Sicherheitshinweise nicht im Text, Temperatur im Schritt',
    () {
      const a = SchokoladeAssistent();
      final r = rezept(a, {'sorte': Schokolade.weiss});
      expect(r.steps.first.text, isNot(contains('warm')));
      expect(r.steps[1].machine!.settings!.temperature, 40);
    },
  );

  test('langer Titel wird UTF-8-sicher gekürzt, Leerzeichen entfernt', () {
    final r = rezept(const SahneAssistent(), {}, titel: '  ${'Ä' * 150}  ');
    expect(utf8.encode(r.title).length, lessThanOrEqualTo(200));
    expect(r.title, 'Ä' * 100);
  });

  test('passt der Plan nicht zum Gerät → kein Rezept', () {
    const plan = AssistentPlan(
      zutaten: [],
      werkzeug: Werkzeug.schneebesen,
      schritte: [PlanSchritt(SchrittArt.schlagen, StufeRef.dauer('9'), 60)],
    );
    expect(
      rezeptAusPlan(
        plan,
        id: 'x',
        titel: 'x',
        portionen: 1,
        caps: caps,
        l10n: l10n,
        jetzt: jetzt,
      ),
      isNull,
    );
  });
}
