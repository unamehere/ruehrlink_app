/// **Alle Zahlen der Assistenten an einer Stelle.**
///
/// Jeder Wert hier ist **vorläufig, an der Maschine prüfen** (KCL95). Echte Werte ermitteln wir im Test,
/// nicht am Schreibtisch (LAUNCH-PLAN „Programme, Assistenten & Sicherheit“). Hinter jedem Wert steht die
/// Quelle:
/// - „Anleitung Z. …“ = `recherche/anleitungen/KCL95_Bedienungsanleitung.txt`, deutscher Teil
///   (nur als Anhaltspunkt, keine Texte übernommen),
/// - „Roadmap“ = `recherche/IDEEN-ROADMAP.md`, Sprint 1,
/// - „Schätzung“ = Annahme ohne Beleg, an der Maschine bzw. beim Backen ermitteln.
///
/// Stufen stehen als Bezeichnung wie am Gerät (`'min'`, `'1'`, … `'max'`, Rührintervall `'1'` …);
/// die App sucht den Gerätewert in `caps` ([StufeRef]), nichts davon ist fest im Code.
library;

import 'assistent.dart';

// ---------------------------------------------------------------------------
// Teig (Pizza, Brot)

/// Mehlsorten des Teig-Rechners.
enum Mehl {
  weizen405,
  weizen550,
  weizen1050,
  weizenVollkorn,
  dinkel630,
  dinkelVollkorn,
}

/// Knet-Werte je Mehlsorte, bezogen auf [TeigWerte.basisMehlG] Mehl.
class MehlWerte {
  const MehlWerte({
    required this.knetStufe,
    required this.knetS,
    required this.hydrationStandard,
    this.ruheS = 0,
    this.ersterKnetAnteil = 1,
    this.quellS = 0,
  });

  /// Stufe beim Kneten.
  final StufeRef knetStufe;

  /// Knetzeit in Sekunden bei [TeigWerte.basisMehlG] (ohne Unterrühren).
  final int knetS;

  /// Ruhephase mitten im Kneten (Motor aus), 0 = keine. Danach Knopf drücken (Fehlerliste F10).
  final int ruheS;

  /// Anteil der Knetzeit vor der Ruhephase (nur mit [ruheS] > 0).
  final double ersterKnetAnteil;

  /// Quellpause nach dem Unterrühren (Vollkorn), 0 = keine.
  final int quellS;

  /// Empfohlene Wassermenge in % vom Mehl.
  final int hydrationStandard;
}

abstract final class TeigWerte {
  /// Bezugsmenge der Knetzeiten. Schätzung (Roadmap: „Startwerte bei 500 g“).
  static const basisMehlG = 500;

  /// Knethaken: kleinste/größte Mehlmenge für festen Hefeteig.
  /// vorläufig, an der Maschine prüfen – Quelle: Anleitung Z. 4241 (350 g – 1,6 kg Mehl).
  static const minMehlG = 350;
  static const maxMehlG = 1600;

  /// Unterrühren vor dem Kneten.
  /// vorläufig, an der Maschine prüfen – Quelle: Anleitung Z. 4241 (Stufe „Min“, 60 s).
  static const unterruehrenStufe = StufeRef.dauer('min');
  static const unterruehrenS = 60;

  /// Knetzeit wächst unterproportional mit der Mehlmenge: Faktor = (Mehl / 500 g) ^ Exponent.
  /// 0,3 ergibt bei 1 kg etwa +23 %. vorläufig, an der Maschine prüfen – Quelle: Roadmap („1 kg ≈ +20–25 %“).
  static const mengenExponent = 0.3;

  /// Mehr Wasser → etwas länger kneten: je Prozentpunkt über/unter der Empfehlung ±1 %, begrenzt.
  /// vorläufig, an der Maschine prüfen – Quelle: Schätzung (Roadmap nennt nur „Hydrationsfaktor“).
  static const hydrationFaktorJeProzent = 0.01;
  static const hydrationFaktorMin = 0.85;
  static const hydrationFaktorMax = 1.15;

  /// Zeiten werden auf so viele Sekunden gerundet. Schätzung (lesbare Zeiten).
  static const rundenS = 15;

  /// Je Mehlsorte. Alle Werte vorläufig, an der Maschine prüfen.
  static const mehl = <Mehl, MehlWerte>{
    // Quelle: Roadmap (Weizen ~8 min gesamt bei 500 g); Anleitung Z. 4241 (Stufe 1, 3–4 min, dann 60 s
    // nachkneten) und Z. 3897 (Kneten 10 min, Stufe Min bis 1). Hydration: Schätzung.
    Mehl.weizen405: MehlWerte(
      knetStufe: StufeRef.dauer('1'),
      knetS: 420,
      hydrationStandard: 60,
    ),
    Mehl.weizen550: MehlWerte(
      knetStufe: StufeRef.dauer('1'),
      knetS: 420,
      hydrationStandard: 65,
    ),
    Mehl.weizen1050: MehlWerte(
      knetStufe: StufeRef.dauer('1'),
      knetS: 420,
      hydrationStandard: 68,
    ),
    // Quelle: Roadmap (Vollkorn ~6 min + 10 min Quellpause). Hydration: Schätzung.
    Mehl.weizenVollkorn: MehlWerte(
      knetStufe: StufeRef.dauer('1'),
      knetS: 300,
      quellS: 600,
      hydrationStandard: 75,
    ),
    // Dinkel: kürzer und langsamer, sonst wird der Teig schmierig (Niklas' Problem).
    // Quelle: Roadmap (Dinkel ~4–5 min, „sanft!“); Stufe „min“, Ruhephase 5 min und Aufteilung 60/40:
    // Schätzung. Hydration: Schätzung (Dinkel nimmt weniger Wasser auf).
    Mehl.dinkel630: MehlWerte(
      knetStufe: StufeRef.dauer('min'),
      knetS: 240,
      ruheS: 300,
      ersterKnetAnteil: 0.6,
      hydrationStandard: 60,
    ),
    // Quelle: wie Dinkel 630, plus Quellpause wie Vollkorn (Roadmap). Schätzung.
    Mehl.dinkelVollkorn: MehlWerte(
      knetStufe: StufeRef.dauer('min'),
      knetS: 210,
      ruheS: 300,
      ersterKnetAnteil: 0.6,
      quellS: 600,
      hydrationStandard: 70,
    ),
  };

  /// Wählbare Hydration in % (Kacheln). Schätzung (übliche Spanne fester bis weicher Hefeteige).
  static const hydrationen = [55, 60, 65, 70, 75, 80];

  /// Mehlmengen für Brot (Kacheln), innerhalb [minMehlG]–[maxMehlG].
  static const brotMehlG = [350, 500, 750, 1000, 1250, 1500];

  /// Salz in % vom Mehl. Schätzung (übliche Bäckerprozente).
  static const salzBrotProzent = 2.0;
  static const salzPizzaProzent = 2.5;

  /// Olivenöl im Pizzateig in % vom Mehl. Schätzung.
  static const oelPizzaProzent = 2.0;

  /// Frische Hefe in % vom Mehl je Gehzeit. Schätzung (übliche Bäckerprozente, temperaturabhängig).
  static const hefeFrischProzent = <Gehzeit, double>{
    Gehzeit.kurz: 2.0, //   ca. 1–2 h bei Raumtemperatur
    Gehzeit.mittel: 0.7, // ca. 4–6 h bei Raumtemperatur
    Gehzeit.lang: 0.2, //   ca. 24 h im Kühlschrank
  };

  /// Trockenhefe = frische Hefe geteilt durch diesen Faktor. Schätzung (Faustregel 7 g ≈ 21 g).
  static const trockenhefeTeiler = 3.0;

  /// Pizza: Teiglinggewicht je Pizza (ca. 30 cm). Schätzung.
  static const pizzaTeiglingG = 250;

  /// Pizza: wählbare Anzahl (Kacheln). Größte Menge bleibt unter [maxMehlG].
  static const pizzaAnzahl = [2, 3, 4, 5, 6, 8];
}

/// Wie lange der Teig gehen darf – bestimmt die Hefemenge.
enum Gehzeit { kurz, mittel, lang }

/// Frische Hefe oder Trockenhefe.
enum Hefe { frisch, trocken }

// ---------------------------------------------------------------------------
// Eischnee

abstract final class EischneeWerte {
  /// Wählbare Anzahl Eiweiß. Höchstmenge Schneebesen: 16 Eiweiß.
  /// vorläufig, an der Maschine prüfen – Quelle: Anleitung Z. 4194.
  static const anzahl = [2, 3, 4, 6, 8, 12, 16];

  /// Gramm je Eiweiß (mittelgroßes Ei). Quelle: Anleitung Z. 4194 (16 Eiweiß ≈ 605 g → ca. 38 g). Schätzung.
  static const gProEiweiss = 38;

  /// Anschlagen langsam, dann schnell.
  /// vorläufig, an der Maschine prüfen – Quelle: Anleitung Z. 4194 (von Min bis Max steigern), Stufe/Zeit: Schätzung.
  static const anschlagenStufe = StufeRef.dauer('3');
  static const anschlagenS = 30;

  /// Schlagen auf höchster Stufe. vorläufig, an der Maschine prüfen –
  /// Quelle: Anleitung Z. 3881 (Programm Eischnee 1:15 auf Max), Z. 4194 (1½–2 min gesamt).
  static const schlagenStufe = StufeRef.dauer('max');
  static const schlagenWeichS = 60;
  static const schlagenSteifS = 90;

  /// Mehr Eiweiß → länger: je Eiweiß über [zuschlagAb] so viele Sekunden, höchstens [schlagenMaxS]. Schätzung.
  static const zuschlagAb = 4;
  static const zuschlagJeEiweissS = 5;
  static const schlagenMaxS = 150;
}

// ---------------------------------------------------------------------------
// Sahne

abstract final class SahneWerte {
  /// Wählbare Mengen in ml. Höchstmenge Schneebesen 2 l.
  /// vorläufig, an der Maschine prüfen – Quelle: Anleitung Z. 4198.
  static const mengenMl = [200, 400, 600, 1000, 1500];

  /// vorläufig, an der Maschine prüfen – Quelle: Anleitung Z. 4198 (Stufe Max); Anschlagen: Schätzung.
  static const anschlagenStufe = StufeRef.dauer('3');
  static const anschlagenS = 20;
  static const schlagenStufe = StufeRef.dauer('max');

  /// Schlagzeit = Grundzeit + je ml. Lieber zu kurz (nachschlagen geht, zurück nicht). Schätzung.
  static const schlagenGrundS = 60;
  static const schlagenJeMlS = 0.12;
  static const schlagenMaxS = 300;
}

// ---------------------------------------------------------------------------
// Schokolade schmelzen

enum Schokolade { zartbitter, vollmilch, weiss }

abstract final class SchokoladeWerte {
  /// Wählbare Mengen in g. Schätzung.
  static const mengenG = [100, 200, 300, 400, 600];

  /// Zieltemperatur je Sorte. vorläufig, an der Maschine prüfen – Quelle: Schätzung (übliche Schmelzgrenzen).
  /// Zum Vergleich: Anleitung Z. 4104 nennt allgemein 60 °C, das Kenwood-Programm Z. 3910 30 °C (25–35 °C).
  /// Klären, was der Schüsselfühler im Vergleich zur Schokolade misst.
  static const temperatur = <Schokolade, int>{
    Schokolade.zartbitter: 50,
    Schokolade.vollmilch: 45,
    Schokolade.weiss: 40,
  };

  /// Rührintervall „1“ = langsam durchgehend. vorläufig, an der Maschine prüfen – Quelle: Anleitung Z. 4118.
  static const stufe = StufeRef.intervall('1');

  /// Zeit = Grundzeit + je 100 g. vorläufig, an der Maschine prüfen –
  /// Quelle: Schätzung; Anleitung Z. 3910 (Kenwood-Programm 10 min, 3 min – 1 h).
  static const grundS = 360;
  static const je100gS = 60;
}

// ---------------------------------------------------------------------------
// B5: Temperatur-Schnellwahl im manuellen Modus

/// Richtwerte als Schnellwahl. Quelle: Anleitung Z. 4104–4114 (bei Spannen die Mitte bzw. untere Grenze).
/// vorläufig, an der Maschine prüfen (zeigt der Schüsselfühler diese Werte für den Inhalt?).
enum Richtwert {
  schmelzen(60), //   Z. 4104
  pochieren(75), //   Z. 4106 (72–82 °C)
  sieden(98), //      Z. 4108 (98–99 °C)
  kochen(100), //     Z. 4110
  sautieren(135), //  Z. 4112 (130–140 °C)
  anbraten(180); //   Z. 4114

  const Richtwert(this.grad);
  final int grad;
}
