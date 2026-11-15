import 'dart:math' as math;

import '../../core/models/models.dart';
import 'assistent.dart';
import 'werte.dart';

/// Die Rechnungen der Assistenten – reines Dart, alle Zahlen aus `werte.dart`.

enum TeigArt { pizza, brot }

/// Mehlmenge für [anzahl] Pizzen: Teiggewicht geteilt durch (1 + alle Zutaten in % vom Mehl),
/// auf 5 g gerundet.
int pizzaMehlG(int anzahl, {required int hydration, required Gehzeit gehzeit}) {
  final teig = anzahl * TeigWerte.pizzaTeiglingG;
  final anteile =
      1 +
      hydration / 100 +
      TeigWerte.salzPizzaProzent / 100 +
      TeigWerte.oelPizzaProzent / 100 +
      TeigWerte.hefeFrischProzent[gehzeit]! / 100;
  return _runde(teig / anteile, 5).round();
}

/// Knetzeit in Sekunden (ohne Unterrühren und Pausen), ungerundet.
double knetzeitS(Mehl mehl, int mehlG, int hydration) {
  final w = TeigWerte.mehl[mehl]!;
  final menge = math.pow(
    mehlG / TeigWerte.basisMehlG,
    TeigWerte.mengenExponent,
  );
  final hf =
      (1 +
              TeigWerte.hydrationFaktorJeProzent *
                  (hydration - w.hydrationStandard))
          .clamp(TeigWerte.hydrationFaktorMin, TeigWerte.hydrationFaktorMax);
  return w.knetS * menge * hf;
}

/// Teig-Rechner: Zutaten und Knetprogramm (Unterrühren → evtl. Quellpause → Kneten, bei Dinkel mit
/// Ruhephase und Nachkneten).
AssistentPlan teigPlan({
  required TeigArt art,
  required Mehl mehl,
  required int mehlG,
  required int hydration,
  required Hefe hefe,
  required Gehzeit gehzeit,
}) {
  final w = TeigWerte.mehl[mehl]!;
  final pizza = art == TeigArt.pizza;
  final salzProzent = pizza
      ? TeigWerte.salzPizzaProzent
      : TeigWerte.salzBrotProzent;
  final hefeFrisch = mehlG * TeigWerte.hefeFrischProzent[gehzeit]! / 100;
  final zutaten = [
    ZutatMenge(Zutat.mehl, mehlG.toDouble(), Einheit.g, sorte: mehl),
    ZutatMenge(Zutat.wasser, _runde(mehlG * hydration / 100, 5), Einheit.g),
    ZutatMenge(Zutat.salz, _runde(mehlG * salzProzent / 100, 1), Einheit.g),
    if (hefe == Hefe.frisch)
      ZutatMenge(Zutat.hefeFrisch, _hefe(hefeFrisch), Einheit.g)
    else
      ZutatMenge(
        Zutat.hefeTrocken,
        _hefe(hefeFrisch / TeigWerte.trockenhefeTeiler),
        Einheit.g,
      ),
    if (pizza)
      ZutatMenge(
        Zutat.olivenoel,
        _runde(mehlG * TeigWerte.oelPizzaProzent / 100, 1),
        Einheit.g,
      ),
  ];

  const r = TeigWerte.rundenS;
  final knet = knetzeitS(mehl, mehlG, hydration);
  final schritte = <PlanSchritt>[
    const PlanSchritt(
      SchrittArt.unterruehren,
      TeigWerte.unterruehrenStufe,
      TeigWerte.unterruehrenS,
    ),
    if (w.quellS > 0)
      PlanSchritt(SchrittArt.quellen, const StufeRef.aus(), w.quellS),
    if (w.ruheS > 0) ...[
      PlanSchritt(
        SchrittArt.kneten,
        w.knetStufe,
        rundeZeit(knet * w.ersterKnetAnteil, r),
      ),
      PlanSchritt(SchrittArt.ruhen, const StufeRef.aus(), w.ruheS),
      PlanSchritt(
        SchrittArt.nachkneten,
        w.knetStufe,
        rundeZeit(knet * (1 - w.ersterKnetAnteil), r),
      ),
    ] else
      PlanSchritt(SchrittArt.kneten, w.knetStufe, rundeZeit(knet, r)),
  ];

  return AssistentPlan(
    zutaten: zutaten,
    werkzeug: Werkzeug.knethaken,
    schritte: schritte,
    hinweise: [
      if (schritte.any((s) => s.ruhe)) Hinweis.knopfNachRuhe,
      if (mehlG < TeigWerte.minMehlG) Hinweis.wenigMehl,
      if (mehlG > TeigWerte.maxMehlG) Hinweis.vielMehl,
    ],
  );
}

/// Eischnee: anschlagen, dann auf höchster Stufe schlagen; länger bei mehr Eiweiß.
AssistentPlan eischneePlan({required int anzahl, required bool steif}) {
  final mehr =
      math.max(0, anzahl - EischneeWerte.zuschlagAb) *
      EischneeWerte.zuschlagJeEiweissS;
  final schlagen = math.min(
    (steif ? EischneeWerte.schlagenSteifS : EischneeWerte.schlagenWeichS) +
        mehr,
    EischneeWerte.schlagenMaxS,
  );
  return AssistentPlan(
    zutaten: [
      ZutatMenge(Zutat.eiweiss, anzahl.toDouble(), Einheit.stueck),
      const ZutatMenge(Zutat.prisesalz, 1, Einheit.prise),
    ],
    werkzeug: Werkzeug.schneebesen,
    schritte: [
      const PlanSchritt(
        SchrittArt.anschlagen,
        EischneeWerte.anschlagenStufe,
        EischneeWerte.anschlagenS,
      ),
      PlanSchritt(
        SchrittArt.schlagen,
        EischneeWerte.schlagenStufe,
        rundeZeit(schlagen.toDouble(), 5),
      ),
    ],
    hinweise: const [Hinweis.fettfrei],
  );
}

/// Sahne schlagen: anschlagen, dann schnell; Zeit wächst mit der Menge.
AssistentPlan sahnePlan({required int ml}) {
  final schlagen = math.min(
    SahneWerte.schlagenGrundS + ml * SahneWerte.schlagenJeMlS,
    SahneWerte.schlagenMaxS.toDouble(),
  );
  return AssistentPlan(
    zutaten: [ZutatMenge(Zutat.sahne, ml.toDouble(), Einheit.ml)],
    werkzeug: Werkzeug.schneebesen,
    schritte: [
      const PlanSchritt(
        SchrittArt.anschlagen,
        SahneWerte.anschlagenStufe,
        SahneWerte.anschlagenS,
      ),
      PlanSchritt(
        SchrittArt.schlagen,
        SahneWerte.schlagenStufe,
        rundeZeit(schlagen, 5),
      ),
    ],
    hinweise: const [Hinweis.lieberKuerzer, Hinweis.spritzschutz],
  );
}

/// Schokolade schmelzen: sanft heizen je Sorte, langsam rühren; Zeit wächst mit der Menge.
AssistentPlan schokoladePlan({required Schokolade sorte, required int g}) {
  final zeit = SchokoladeWerte.grundS + g / 100 * SchokoladeWerte.je100gS;
  return AssistentPlan(
    zutaten: [
      ZutatMenge(Zutat.schokolade, g.toDouble(), Einheit.g, sorte: sorte),
    ],
    werkzeug: Werkzeug.kochRuehrelement,
    schritte: [
      PlanSchritt(
        SchrittArt.schmelzen,
        SchokoladeWerte.stufe,
        rundeZeit(zeit, 30),
        temperatur: SchokoladeWerte.temperatur[sorte]!,
      ),
    ],
    hinweise: const [Hinweis.schokoladeHacken, Hinweis.warmhalten],
  );
}

double _runde(double x, double auf) => (x / auf).round() * auf;

/// Hefe auf 0,5 g, mindestens 0,5 g.
double _hefe(double g) => math.max(0.5, _runde(g, 0.5));
