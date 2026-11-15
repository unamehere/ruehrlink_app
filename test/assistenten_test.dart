// Rechenlogik der Assistenten: Zutaten, Skalierung, Programmerzeugung.
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/core/api/fake_bridge_api.dart';
import 'package:ruehrlink/core/models/models.dart';
import 'package:ruehrlink/features/assistenten/assistent.dart';
import 'package:ruehrlink/features/assistenten/katalog.dart';
import 'package:ruehrlink/features/assistenten/rechner.dart';
import 'package:ruehrlink/features/assistenten/sicherheit.dart';
import 'package:ruehrlink/features/assistenten/temperatur_schnellwahl.dart';
import 'package:ruehrlink/features/assistenten/werte.dart';
import 'package:ruehrlink/l10n/app_localizations.dart';
import 'package:ruehrlink/ui/illustrations.dart';

const caps = FakeBridgeApi.demoCaps;
final l10n = lookupAppLocalizations(const Locale('de'));

AssistentPlan teig(
  Mehl mehl, {
  int g = 500,
  int? hydration,
  Hefe hefe = Hefe.frisch,
  Gehzeit gehzeit = Gehzeit.kurz,
  TeigArt art = TeigArt.brot,
}) => teigPlan(
  art: art,
  mehl: mehl,
  mehlG: g,
  hydration: hydration ?? TeigWerte.mehl[mehl]!.hydrationStandard,
  hefe: hefe,
  gehzeit: gehzeit,
);

double menge(AssistentPlan p, Zutat z) => p.zutat(z)!.menge;

int knetSumme(AssistentPlan p) => p.schritte
    .where((s) => s.art == SchrittArt.kneten || s.art == SchrittArt.nachkneten)
    .fold(0, (a, s) => a + s.zeitS);

/// Prüft ein Programm wie die Brücke (`sequencer.c` → validate).
void expectGueltig(Program p) {
  expect(p.steps, isNotEmpty);
  expect(p.steps.length, lessThanOrEqualTo(20));
  expect(p.totalTime, lessThanOrEqualTo(caps.timeMaxS));
  final first = p.steps.first.settings;
  expect(first.speed == 0 && first.temperature == 0, isFalse);
  for (final s in p.steps) {
    expect(caps.clamp(s.settings), s.settings);
    expect(s.settings.time, greaterThan(0));
    if (s.settings.temperature >= caps.hotTemp!) {
      expect(caps.tooFastWhenHot(s.settings.speed), isFalse);
    }
    expect(utf8.encode(s.label).length, lessThanOrEqualTo(31));
  }
  expect(utf8.encode(p.name).length, lessThanOrEqualTo(39));
}

void main() {
  group('Teig-Rechner', () {
    test('Weizen 550, 500 g: Zutaten nach Bäckerprozenten', () {
      final p = teig(Mehl.weizen550);
      expect(menge(p, Zutat.mehl), 500);
      expect(menge(p, Zutat.wasser), 325); // 65 %
      expect(menge(p, Zutat.salz), 10); // 2 %
      expect(menge(p, Zutat.hefeFrisch), 10); // 2 % bei kurzer Gehzeit
      expect(p.zutat(Zutat.olivenoel), isNull);
      expect(p.werkzeug, Werkzeug.knethaken);
    });

    test('Weizen: Unterrühren, dann durchgehend kneten', () {
      final p = teig(Mehl.weizen550);
      expect(p.schritte, [
        const PlanSchritt(SchrittArt.unterruehren, StufeRef.dauer('min'), 60),
        const PlanSchritt(SchrittArt.kneten, StufeRef.dauer('1'), 420),
      ]);
      expect(p.hinweise, isNot(contains(Hinweis.knopfNachRuhe)));
    });

    test('Dinkel knetet kürzer und langsamer, mit Ruhephase', () {
      final dinkel = teig(Mehl.dinkel630);
      final weizen = teig(Mehl.weizen550);
      expect(knetSumme(dinkel), lessThan(knetSumme(weizen)));
      final arten = dinkel.schritte.map((s) => s.art).toList();
      expect(arten, [
        SchrittArt.unterruehren,
        SchrittArt.kneten,
        SchrittArt.ruhen,
        SchrittArt.nachkneten,
      ]);
      final kneten = dinkel.schritte[1];
      expect(kneten.stufe, const StufeRef.dauer('min'));
      expect(dinkel.schritte[2].ruhe, isTrue);
      // langsamere Stufe als Weizen (Reihenfolge am Gerät)
      final dv = kneten.stufe.aufloesen(caps)!;
      final wv = weizen.schritte[1].stufe.aufloesen(caps)!;
      final idx = caps.speeds.indexWhere;
      expect(idx((o) => o.v == dv), lessThan(idx((o) => o.v == wv)));
      expect(dinkel.hinweise, contains(Hinweis.knopfNachRuhe));
    });

    test('Vollkorn: Quellpause nach dem Unterrühren', () {
      final p = teig(Mehl.weizenVollkorn);
      expect(p.schritte[1].art, SchrittArt.quellen);
      expect(p.schritte[1].ruhe, isTrue);
      expect(p.schritte[1].zeitS, 600);
      expect(p.hinweise, contains(Hinweis.knopfNachRuhe));
    });

    test('Knetzeit wächst unterproportional mit der Mehlmenge', () {
      final k500 = knetzeitS(Mehl.weizen550, 500, 65);
      final k1000 = knetzeitS(Mehl.weizen550, 1000, 65);
      expect(k1000 / k500, inInclusiveRange(1.20, 1.25));
      expect(knetzeitS(Mehl.weizen550, 350, 65), lessThan(k500));
      expect(
        knetSumme(teig(Mehl.weizen550, g: 1000)),
        greaterThan(knetSumme(teig(Mehl.weizen550))),
      );
    });

    test('Mehr Wasser → etwas länger kneten, begrenzt', () {
      final std = knetzeitS(Mehl.weizen550, 500, 65);
      expect(knetzeitS(Mehl.weizen550, 500, 75), closeTo(std * 1.10, 0.01));
      expect(knetzeitS(Mehl.weizen550, 500, 95), closeTo(std * 1.15, 0.01));
      expect(knetzeitS(Mehl.weizen550, 500, 40), closeTo(std * 0.85, 0.01));
    });

    test('Zeiten auf 15 s gerundet', () {
      for (final m in Mehl.values) {
        for (final g in TeigWerte.brotMehlG) {
          for (final s in teig(m, g: g).schritte) {
            expect(s.zeitS % 15, 0, reason: '$m $g g $s');
          }
        }
      }
    });

    test('Trockenhefe ist ein Drittel, auf 0,5 g, mindestens 0,5 g', () {
      expect(
        menge(teig(Mehl.weizen550, hefe: Hefe.trocken), Zutat.hefeTrocken),
        3.5,
      );
      expect(
        menge(
          teig(Mehl.weizen550, hefe: Hefe.trocken, gehzeit: Gehzeit.lang),
          Zutat.hefeTrocken,
        ),
        0.5,
      );
      expect(
        menge(teig(Mehl.weizen550, gehzeit: Gehzeit.lang), Zutat.hefeFrisch),
        1,
      );
    });

    test('Mengen-Hinweise an den Grenzen des Knethakens', () {
      expect(
        teig(Mehl.weizen550, g: 300).hinweise,
        contains(Hinweis.wenigMehl),
      );
      expect(
        teig(Mehl.weizen550, g: 1700).hinweise,
        contains(Hinweis.vielMehl),
      );
      expect(
        teig(Mehl.weizen550, g: 1500).hinweise,
        isNot(contains(Hinweis.vielMehl)),
      );
    });

    test('Pizza: Mehl aus Anzahl, mit Öl', () {
      final g = pizzaMehlG(4, hydration: 60, gehzeit: Gehzeit.mittel);
      expect(g, 605); // 1000 g Teig / 1,652
      final p = teig(
        Mehl.weizen405,
        g: g,
        hydration: 60,
        gehzeit: Gehzeit.mittel,
        art: TeigArt.pizza,
      );
      final teiggewicht = p.zutaten.fold<double>(0, (a, z) => a + z.menge);
      expect(teiggewicht, closeTo(1000, 15));
      expect(menge(p, Zutat.olivenoel), 12);
      expect(menge(p, Zutat.salz), 15);
      // größte Auswahl bleibt unter der Höchstmenge
      final max = pizzaMehlG(
        TeigWerte.pizzaAnzahl.last,
        hydration: TeigWerte.hydrationen.first,
        gehzeit: Gehzeit.kurz,
      );
      expect(max, lessThanOrEqualTo(TeigWerte.maxMehlG));
    });
  });

  group('Einfache Assistenten', () {
    test('Eischnee: steif länger, mehr Eiweiß länger, gedeckelt', () {
      expect(eischneePlan(anzahl: 4, steif: true).schritte.last.zeitS, 90);
      expect(eischneePlan(anzahl: 2, steif: false).schritte.last.zeitS, 60);
      expect(eischneePlan(anzahl: 8, steif: true).schritte.last.zeitS, 110);
      expect(
        eischneePlan(anzahl: 16, steif: true).schritte.last.zeitS,
        EischneeWerte.schlagenMaxS,
      );
      final p = eischneePlan(anzahl: 4, steif: true);
      expect(p.schritte.last.stufe, const StufeRef.dauer('max'));
      expect(p.werkzeug, Werkzeug.schneebesen);
      expect(menge(p, Zutat.eiweiss), 4);
    });

    test('Sahne: Zeit wächst mit der Menge, gedeckelt', () {
      expect(sahnePlan(ml: 200).schritte.last.zeitS, 85);
      expect(sahnePlan(ml: 1000).schritte.last.zeitS, 180);
      expect(sahnePlan(ml: 1500).schritte.last.zeitS, 240);
      expect(sahnePlan(ml: 5000).schritte.last.zeitS, SahneWerte.schlagenMaxS);
    });

    test('Schokolade: Temperatur je Sorte, Zeit je Menge', () {
      final p = schokoladePlan(sorte: Schokolade.weiss, g: 200);
      expect(p.schritte.single.temperatur, 40);
      expect(p.schritte.single.zeitS, 480);
      expect(p.schritte.single.stufe, const StufeRef.intervall('1'));
      expect(
        schokoladePlan(
          sorte: Schokolade.zartbitter,
          g: 200,
        ).schritte.single.temperatur,
        greaterThan(p.schritte.single.temperatur),
      );
      // Alle Sorten unter der Heiß-Grenze
      for (final t in SchokoladeWerte.temperatur.values) {
        expect(t, lessThan(caps.hotTemp!));
      }
    });
  });

  group('Programm erzeugen', () {
    test('Stufen kommen aus caps', () {
      expect(const StufeRef.dauer('min').aufloesen(caps), 5);
      expect(const StufeRef.dauer('1').aufloesen(caps), 6);
      expect(const StufeRef.dauer('max').aufloesen(caps), 12);
      expect(const StufeRef.intervall('1').aufloesen(caps), 4);
      expect(const StufeRef.aus().aufloesen(caps), 0);
      expect(const StufeRef.dauer('9').aufloesen(caps), isNull);
    });

    test('Dinkelteig → Programm mit Beschriftungen', () {
      final p = programmAusPlan(
        teig(Mehl.dinkel630),
        name: 'Teig',
        caps: caps,
        l10n: l10n,
      )!;
      expect(p.steps.map((s) => s.label), [
        'Unterrühren',
        'Kneten',
        'Ruhen',
        'Nachkneten',
      ]);
      expect(p.steps.map((s) => s.settings.speed), [5, 5, 0, 5]);
      expect(p.steps[2].settings.temperature, 0);
      expect(p.toJson()['id'], '');
      expectGueltig(p);
    });

    test('Jeder Assistent mit Vorschlägen und jeder Option ergibt ein gültiges Programm', () {
      for (final a in alleAssistenten) {
        final antworten = <Antworten>[{}];
        for (final f in a.fragen) {
          for (final o in f.optionen(const {})) {
            antworten.add({f.id: o.wert});
          }
        }
        for (final x in antworten) {
          final plan = a.plan(x);
          final p = programmAusPlan(
            plan,
            name: a.programmName(l10n, x),
            caps: caps,
            l10n: l10n,
          );
          expect(p, isNotNull, reason: '${a.id} $x');
          expectGueltig(p!);
          // Programm-Karte findet ein passendes Bild über den Namen
          expect(Illustrations.forName(p.name), isNotNull, reason: p.name);
        }
      }
    });

    test('Unbekannte Stufe → kein Programm', () {
      const plan = AssistentPlan(
        zutaten: [],
        werkzeug: Werkzeug.schneebesen,
        schritte: [PlanSchritt(SchrittArt.schlagen, StufeRef.dauer('9'), 60)],
      );
      expect(programmAusPlan(plan, name: 'x', caps: caps, l10n: l10n), isNull);
    });

    test('Vorschlag folgt früheren Antworten (Wasser je Mehl)', () {
      const a = TeigAssistent();
      expect(a.wert<int>({'mehl': Mehl.dinkel630}, 'wasser'), 60);
      expect(a.wert<int>({'mehl': Mehl.weizenVollkorn}, 'wasser'), 75);
      expect(a.wert<int>({'mehl': Mehl.dinkel630, 'wasser': 70}, 'wasser'), 70);
    });

    test('Namen werden UTF-8-sicher gekürzt', () {
      final s = kuerzeUtf8('Ä' * 30, 39);
      expect(utf8.encode(s).length, lessThanOrEqualTo(39));
      expect(s, 'Ä' * 19);
      expect(kuerzeUtf8('kurz', 39), 'kurz');
      final name = const TeigAssistent().programmName(l10n, {
        'mehl': Mehl.dinkelVollkorn,
        'menge': 1500,
      });
      expect(utf8.encode(kuerzeUtf8(name, 39)).length, lessThanOrEqualTo(39));
    });
  });

  group('Sicherheitshinweise und Schnellwahl', () {
    test('Abschaltbar, Tipps bleiben', () {
      expect(
        zeigeHinweis(Hinweis.spritzschutz, SicherheitsHinweise.alle),
        isTrue,
      );
      expect(
        zeigeHinweis(Hinweis.spritzschutz, SicherheitsHinweise.kritische),
        isFalse,
      );
      expect(
        zeigeHinweis(Hinweis.vielMehl, SicherheitsHinweise.kritische),
        isTrue,
      );
      expect(
        zeigeHinweis(Hinweis.spritzschutz, SicherheitsHinweise.aus),
        isFalse,
      );
      expect(zeigeHinweis(Hinweis.vielMehl, SicherheitsHinweise.aus), isFalse);
      expect(
        zeigeHinweis(Hinweis.knopfNachRuhe, SicherheitsHinweise.aus),
        isTrue,
      );
    });

    test('Richtwert setzt Temperatur, senkt zu schnelle Stufe bei Hitze', () {
      const s = MachineSettings(temperature: 0, time: 600, speed: 10);
      expect(
        waehleRichtwert(caps, s, Richtwert.anbraten.grad),
        const MachineSettings(temperature: 180, time: 600, speed: 7),
      );
      const langsam = MachineSettings(temperature: 0, time: 60, speed: 4);
      expect(
        waehleRichtwert(caps, langsam, Richtwert.kochen.grad),
        const MachineSettings(temperature: 100, time: 60, speed: 4),
      );
      for (final r in Richtwert.values) {
        expect(caps.clampTemperature(r.grad), r.grad);
      }
    });
  });
}
