import 'dart:convert';

import '../../core/models/models.dart';
import '../../l10n/l10n.dart';

/// Rahmen der Assistenten (Entscheidung 12.11., `ruehrlink_esp/docs/api.md` → „Assistenten“):
/// Ein Assistent stellt wenige Fragen, rechnet daraus Zutaten und einen Ablauf ([AssistentPlan]) und
/// erzeugt ein Programm, das die App inline an `POST /api/v1/sequence/start` schickt. Die Brücke prüft es
/// wie jedes andere Programm. Die Rechnung ist reines Dart (ohne Flutter), damit sie testbar bleibt.

/// Stufe als Bezeichnung wie am Gerät. Den Gerätewert liefert erst `caps` ([aufloesen]) – so steht
/// nichts Gerätespezifisches im Code der Assistenten.
class StufeRef {
  const StufeRef.dauer(this.label) : gruppe = SpeedGroup.continuous;
  const StufeRef.intervall(this.label) : gruppe = SpeedGroup.stir;
  const StufeRef.aus() : label = '', gruppe = SpeedGroup.off;

  final SpeedGroup gruppe;
  final String label;

  bool get aus => gruppe == SpeedGroup.off;

  /// Gerätewert `v` aus [caps] oder `null`, wenn das Gerät diese Stufe nicht kennt.
  int? aufloesen(ApplianceCaps caps) {
    for (final o in caps.speeds) {
      if (o.group == gruppe && (aus || o.label == label)) return o.v;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is StufeRef && other.gruppe == gruppe && other.label == label;

  @override
  int get hashCode => Object.hash(gruppe, label);

  @override
  String toString() => 'StufeRef(${gruppe.name} $label)';
}

/// Was ein Programmschritt tut – daraus wird die Beschriftung.
enum SchrittArt {
  unterruehren,
  quellen,
  kneten,
  ruhen,
  nachkneten,
  anschlagen,
  schlagen,
  schmelzen,
}

/// Ein Schritt des Ablaufs, noch geräteneutral.
class PlanSchritt {
  const PlanSchritt(this.art, this.stufe, this.zeitS, {this.temperatur = 0});

  final SchrittArt art;
  final StufeRef stufe;
  final int zeitS;

  /// °C, 0 = nicht heizen.
  final int temperatur;

  /// Motor aus: danach muss am Gerät der Knopf gedrückt werden (Fehlerliste F10).
  bool get ruhe => stufe.aus;

  @override
  bool operator ==(Object other) =>
      other is PlanSchritt &&
      other.art == art &&
      other.stufe == stufe &&
      other.zeitS == zeitS &&
      other.temperatur == temperatur;

  @override
  int get hashCode => Object.hash(art, stufe, zeitS, temperatur);

  @override
  String toString() =>
      'PlanSchritt(${art.name}, $stufe, $zeitS s, $temperatur °C)';
}

enum Zutat {
  mehl,
  wasser,
  salz,
  hefeFrisch,
  hefeTrocken,
  olivenoel,
  eiweiss,
  prisesalz,
  sahne,
  schokolade,
}

enum Einheit { g, ml, stueck, prise }

/// Eine Zutat mit Menge. [sorte] verfeinert den Namen (z. B. `Mehl.dinkel630`).
class ZutatMenge {
  const ZutatMenge(this.zutat, this.menge, this.einheit, {this.sorte});

  final Zutat zutat;
  final double menge;
  final Einheit einheit;
  final Object? sorte;

  @override
  String toString() =>
      '${zutat.name}${sorte == null ? '' : '($sorte)'} '
      '$menge ${einheit.name}';
}

/// Hinweise im Ergebnis. [sicherheit]-Hinweise lassen sich abschalten (Grundsatz im Backlog:
/// „Rührlink soll nicht nerven“), [kritisch] nur mit „aus“. Tipps und Ablauf-Infos bleiben.
enum Hinweis {
  knopfNachRuhe,
  wenigMehl,
  vielMehl(
    sicherheit: true,
    kritisch: true,
  ), // Überlastung des Motors (Anleitung Z. 4226–4228)
  fettfrei,
  lieberKuerzer,
  schokoladeHacken,
  warmhalten(sicherheit: true),
  spritzschutz(sicherheit: true);

  const Hinweis({this.sicherheit = false, this.kritisch = false});

  final bool sicherheit;
  final bool kritisch;
}

/// Ergebnis eines Assistenten: Zutaten, Werkzeug, Ablauf, Hinweise.
class AssistentPlan {
  const AssistentPlan({
    required this.zutaten,
    required this.werkzeug,
    required this.schritte,
    this.hinweise = const [],
  });

  final List<ZutatMenge> zutaten;
  final Werkzeug werkzeug;
  final List<PlanSchritt> schritte;
  final List<Hinweis> hinweise;

  int get gesamtS => schritte.fold(0, (s, x) => s + x.zeitS);

  ZutatMenge? zutat(Zutat z) {
    for (final m in zutaten) {
      if (m.zutat == z) return m;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Fragen

typedef Antworten = Map<String, Object>;
typedef L10nText = String Function(AppLocalizations l10n);

/// Eine Antwortmöglichkeit als große Kachel.
class Option {
  const Option(this.wert, this.text, {this.detail, this.bild});

  final Object wert;
  final L10nText text;
  final L10nText? detail;

  /// Illustration (Asset-Pfad) oder `null`.
  final String? bild;
}

/// Eine Frage. Optionen und Vorschlag dürfen von früheren Antworten abhängen
/// (z. B. empfohlene Wassermenge je Mehlsorte).
class Frage {
  const Frage({
    required this.id,
    required this.titel,
    required this.optionen,
    required this.standard,
    this.detail,
  });

  final String id;
  final L10nText titel;
  final L10nText? detail;
  final List<Option> Function(Antworten a) optionen;
  final Object Function(Antworten a) standard;
}

/// Ein Assistent: Fragen → [plan].
abstract class Assistent {
  const Assistent();

  String get id;
  String titel(AppLocalizations l10n);
  String untertitel(AppLocalizations l10n);
  String get bild;
  List<Frage> get fragen;

  /// Name des Programms auf der Brücke (kurz, z. B. „Pizzateig für 4“).
  String programmName(AppLocalizations l10n, Antworten a);

  /// Vorschlag für den Titel bei „Als Rezept speichern“ (z. B. „Meine Pizza“).
  String rezeptTitel(AppLocalizations l10n);

  /// Portionen des gespeicherten Rezepts (z. B. Anzahl Pizzen), sonst 1.
  int portionen(Antworten a) => 1;

  /// Zutaten und Ablauf aus den Antworten. Fehlende Antworten → Vorschlag der Frage.
  AssistentPlan plan(Antworten a);

  /// Antwort auf [frageId] – gewählt oder vorgeschlagen.
  T wert<T extends Object>(Antworten a, String frageId) {
    final gewaehlt = a[frageId];
    if (gewaehlt is T) return gewaehlt;
    return fragen.firstWhere((f) => f.id == frageId).standard(a) as T;
  }
}

// ---------------------------------------------------------------------------
// Programm erzeugen

/// Größen der Brücke (`sequencer.h`, `api.c`): Name 40 Byte, Beschriftung 32 Byte inkl. Nullbyte, UTF-8.
const programmNameMaxBytes = 39;
const schrittLabelMaxBytes = 31;

/// Kürzt auf [maxBytes] UTF-8-Bytes, ohne ein Zeichen zu zerschneiden.
String kuerzeUtf8(String s, int maxBytes) {
  if (utf8.encode(s).length <= maxBytes) return s;
  final runes = s.runes.toList();
  while (runes.isNotEmpty &&
      utf8.encode(String.fromCharCodes(runes)).length > maxBytes) {
    runes.removeLast();
  }
  return String.fromCharCodes(runes).trimRight();
}

/// Plan → Programm für die Brücke. `null`, wenn eine Stufe am Gerät fehlt oder ein Wert nicht in `caps`
/// passt (dann ist der Assistent für dieses Gerät nicht geeignet).
Program? programmAusPlan(
  AssistentPlan plan, {
  required String name,
  required ApplianceCaps caps,
  required AppLocalizations l10n,
}) {
  final schritte = <ProgramStep>[];
  for (final s in plan.schritte) {
    final v = s.stufe.aufloesen(caps);
    if (v == null) return null;
    final settings = MachineSettings(
      temperature: s.temperatur,
      time: s.zeitS,
      speed: v,
    );
    if (caps.clamp(settings) != settings || s.zeitS <= 0) return null;
    schritte.add(
      ProgramStep(
        settings: settings,
        label: kuerzeUtf8(schrittLabel(l10n, s.art), schrittLabelMaxBytes),
      ),
    );
  }
  if (schritte.isEmpty || plan.gesamtS > caps.timeMaxS) return null;
  return Program(
    id: '',
    name: kuerzeUtf8(name, programmNameMaxBytes),
    steps: schritte,
  );
}

String schrittLabel(AppLocalizations l10n, SchrittArt art) => switch (art) {
  SchrittArt.unterruehren => l10n.asStepMix,
  SchrittArt.quellen => l10n.asStepSoak,
  SchrittArt.kneten => l10n.asStepKnead,
  SchrittArt.ruhen => l10n.asStepRest,
  SchrittArt.nachkneten => l10n.asStepKneadAgain,
  SchrittArt.anschlagen => l10n.asStepStartWhip,
  SchrittArt.schlagen => l10n.asStepWhip,
  SchrittArt.schmelzen => l10n.asStepMelt,
};

/// Auf [schritt] Sekunden runden, mindestens [schritt].
int rundeZeit(double sekunden, int schritt) {
  final r = (sekunden / schritt).round() * schritt;
  return r < schritt ? schritt : r;
}
