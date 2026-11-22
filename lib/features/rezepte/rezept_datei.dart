// Rezept-Datei `.rlrezept` zum Teilen: dasselbe JSON wie `GET /api/v1/recipes/{id}`, dazu
// `schema` (Version des Dateiformats) und die Fotos als Base64 unter `media` (Schlüssel = SHA-256).
//
// Reine Logik ohne Flutter-Oberfläche – Lesen, Schreiben, Übernahme vorbereiten. Unit-Tests in
// test/rezept_datei_test.dart.

import 'dart:convert';
import 'dart:typed_data';

import '../../core/models/json.dart';
import '../../core/models/models.dart';
import 'recipe_library.dart' show fitUtf8, sha256Hex;

/// Dateiendung (mit Punkt).
const rezeptDateiEndung = '.rlrezept';

/// MIME-Typ beim Teilen; „Öffnen mit Rührlink“ erkennt ihn (AndroidManifest.xml).
const rezeptDateiMime = 'application/vnd.ruehrlink.rezept';

/// Aktuelle Version des Dateiformats. Neuere Dateien werden trotzdem gelesen (mit Hinweis).
const rezeptDateiSchema = 1;

/// Grenzen der Brücke (ruehrlink_esp/docs/api.md, Rezepte und Fotos).
abstract final class RezeptGrenzen {
  /// Ganze Datei inkl. Fotos – mehr nimmt die App gar nicht erst an.
  static const dateiBytes = 16 * 1024 * 1024;

  /// Rezept-JSON beim Speichern (`PUT /recipes/{id}`).
  static const rezeptBytes = 16 * 1024;
  static const fotoBytes = 1024 * 1024;
  static const titelBytes = 200;
  static const portionenMax = 1000;
  static const tags = 50;
  static const schritte = 200;
  static const zutatenJeSchritt = 50;
}

enum RezeptDateiFehler {
  /// Leere Datei.
  leer,

  /// Größer als [RezeptGrenzen.dateiBytes].
  zuGross,

  /// Kein (lesbares) JSON – z. B. eine ganz andere Datei oder abgeschnitten.
  kaputt,

  /// JSON, aber kein Rezept (kein Titel).
  keinRezept,

  /// Rezept ohne Fotos größer als die Brücke speichern kann.
  rezeptZuGross,
}

class RezeptDateiException implements Exception {
  const RezeptDateiException(this.fehler);
  final RezeptDateiFehler fehler;

  @override
  String toString() => 'RezeptDateiException(${fehler.name})';
}

/// Was beim Lesen auffiel – nichts davon verhindert die Übernahme.
class RezeptDateiHinweise {
  const RezeptDateiHinweise({
    this.neueresFormat = false,
    this.unbekannteWerkzeuge = const [],
    this.fehlendeFotos = 0,
    this.gekuerzt = false,
  });

  /// `schema` größer als [rezeptDateiSchema]: Unbekanntes wird weggelassen.
  final bool neueresFormat;

  /// Schritte (ab 1), deren Werkzeug diese App nicht kennt – der Schritt bleibt, ohne Werkzeug.
  final List<int> unbekannteWerkzeuge;

  /// Fotos, auf die das Rezept verweist, die aber fehlen oder beschädigt sind (werden weggelassen).
  final int fehlendeFotos;

  /// Mehr Schritte/Zutaten/Tags oder längerer Titel, als die Brücke annimmt → gekürzt.
  final bool gekuerzt;

  bool get keine =>
      !neueresFormat &&
      unbekannteWerkzeuge.isEmpty &&
      fehlendeFotos == 0 &&
      !gekuerzt;
}

/// Gelesene Rezept-Datei: das Rezept (noch mit der ID aus der Datei) und seine Fotos.
class RezeptDatei {
  const RezeptDatei({
    required this.recipe,
    this.photos = const {},
    this.schema = rezeptDateiSchema,
    this.hinweise = const RezeptDateiHinweise(),
  });

  final Recipe recipe;

  /// SHA-256 → WebP, nur geprüfte Fotos, auf die [recipe] verweist.
  final Map<String, Uint8List> photos;
  final int schema;
  final RezeptDateiHinweise hinweise;

  /// Datei lesen. Kaputte Daten → [RezeptDateiException]; Unbekanntes (Werkzeug, neueres Format)
  /// wird toleriert und in [hinweise] vermerkt.
  static RezeptDatei lesen(List<int> bytes) {
    if (bytes.isEmpty) throw const RezeptDateiException(RezeptDateiFehler.leer);
    if (bytes.length > RezeptGrenzen.dateiBytes) {
      throw const RezeptDateiException(RezeptDateiFehler.zuGross);
    }
    Object? decoded;
    try {
      var text = utf8.decode(bytes);
      if (text.startsWith('﻿')) text = text.substring(1); // BOM
      decoded = jsonDecode(text);
    } on FormatException {
      throw const RezeptDateiException(RezeptDateiFehler.kaputt);
    }
    if (decoded is! Map) {
      throw const RezeptDateiException(RezeptDateiFehler.keinRezept);
    }
    final json = decoded.cast<String, dynamic>();
    final title = json['title'];
    if (title is! String || title.trim().isEmpty) {
      throw const RezeptDateiException(RezeptDateiFehler.keinRezept);
    }
    final schema = readInt(json['schema'], rezeptDateiSchema);

    // Werkzeuge, die diese App nicht kennt (neuere App, Zubehör): Schritt behalten, Hinweis.
    final rawSteps = json['steps'] is List ? json['steps'] as List : const [];
    final unbekannt = <int>[];
    for (final (n, s) in rawSteps.indexed) {
      if (s is Map &&
          s['tool'] is String &&
          Werkzeug.fromJson(s['tool']) == null) {
        unbekannt.add(n + 1);
      }
    }

    Recipe recipe;
    try {
      recipe = Recipe.fromJson(json);
    } on Object {
      throw const RezeptDateiException(RezeptDateiFehler.keinRezept);
    }

    // Fotos: nur, was zur Prüfsumme passt, nicht zu groß und WebP ist.
    final media = <String, Uint8List>{};
    readMap(json['media']).forEach((sha, v) {
      if (v is! String) return;
      try {
        final b = base64Decode(v);
        if (b.length <= RezeptGrenzen.fotoBytes &&
            _isWebp(b) &&
            sha256Hex(b) == sha.toLowerCase()) {
          media[sha.toLowerCase()] = b;
        }
      } on FormatException {
        // beschädigt → weglassen
      }
    });
    var fehlend = 0;
    String? photoOrNull(String? sha) {
      if (sha == null) return null;
      if (media.containsKey(sha.toLowerCase())) return sha.toLowerCase();
      fehlend++;
      return null;
    }

    // Auf die Grenzen der Brücke bringen.
    var gekuerzt = false;
    final fitTitle = fitUtf8(recipe.title.trim(), RezeptGrenzen.titelBytes);
    if (fitTitle != recipe.title.trim()) gekuerzt = true;
    var steps = recipe.steps;
    if (steps.length > RezeptGrenzen.schritte) {
      steps = steps.take(RezeptGrenzen.schritte).toList();
      gekuerzt = true;
    }
    steps = [
      for (final s in steps)
        RecipeStep(
          text: s.text,
          photo: photoOrNull(s.photo),
          ingredients: s.ingredients.length > RezeptGrenzen.zutatenJeSchritt
              ? (() {
                  gekuerzt = true;
                  return s.ingredients
                      .take(RezeptGrenzen.zutatenJeSchritt)
                      .toList();
                })()
              : s.ingredients,
          tool: s.tool,
          machine: s.machine,
        ),
    ];
    var tags = recipe.tags;
    if (tags.length > RezeptGrenzen.tags) {
      tags = tags.take(RezeptGrenzen.tags).toList();
      gekuerzt = true;
    }
    final cleaned = Recipe(
      id: recipe.id,
      rev: recipe.rev,
      updated: recipe.updated,
      title: fitTitle,
      servings: recipe.servings.clamp(1, RezeptGrenzen.portionenMax),
      photo: photoOrNull(recipe.photo),
      tags: tags,
      steps: steps,
    );
    _pruefeGroesse(cleaned);

    final used = {?cleaned.photo, for (final s in cleaned.steps) ?s.photo};
    return RezeptDatei(
      recipe: cleaned,
      photos: {for (final sha in used) sha: media[sha]!},
      schema: schema,
      hinweise: RezeptDateiHinweise(
        neueresFormat: schema > rezeptDateiSchema,
        unbekannteWerkzeuge: unbekannt,
        fehlendeFotos: fehlend,
        gekuerzt: gekuerzt,
      ),
    );
  }

  /// Datei schreiben. [photos] = SHA-256 → WebP; Verweise auf Fotos, die fehlen, werden
  /// weggelassen (der Empfänger könnte sie sonst nicht anzeigen).
  static Uint8List schreiben(Recipe recipe, Map<String, Uint8List> photos) {
    String? keep(String? sha) =>
        sha != null && photos[sha] != null ? sha : null;
    final r = Recipe(
      id: recipe.id,
      rev: recipe.rev,
      updated: recipe.updated,
      title: recipe.title,
      servings: recipe.servings,
      photo: keep(recipe.photo),
      tags: recipe.tags,
      steps: [
        for (final s in recipe.steps)
          RecipeStep(
            text: s.text,
            photo: keep(s.photo),
            ingredients: s.ingredients,
            tool: s.tool,
            machine: s.machine,
          ),
      ],
    );
    final used = {?r.photo, for (final s in r.steps) ?s.photo};
    final json = <String, dynamic>{
      'schema': rezeptDateiSchema,
      ...r.toJson(),
      if (used.isNotEmpty)
        'media': {for (final sha in used) sha: base64Encode(photos[sha]!)},
    };
    return utf8.encode(const JsonEncoder.withIndent('  ').convert(json));
  }
}

/// Rezept ohne Fotos muss in einen `PUT /recipes/{id}` passen.
void _pruefeGroesse(Recipe r) {
  if (utf8.encode(jsonEncode(r.toJson())).length > RezeptGrenzen.rezeptBytes) {
    throw const RezeptDateiException(RezeptDateiFehler.rezeptZuGross);
  }
}

bool _isWebp(Uint8List b) =>
    b.length >= 12 &&
    ascii.decode(b.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
    ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WEBP';

/// Dateiname zum Teilen: `Pizzateig.rlrezept`. Zeichen, die Dateisysteme oder Mail-Programme
/// nicht mögen, fallen weg; Umlaute bleiben.
String rezeptDateiName(String title) {
  var name = title
      .replaceAll(RegExp(r'[\x00-\x1F\x7F<>:"/\\|?*]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  // Keine führenden/abschließenden Punkte (versteckte Datei, Windows).
  name = name.replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');
  name = fitUtf8(name, 80).trim();
  if (name.isEmpty) name = 'Rezept';
  return '$name$rezeptDateiEndung';
}

/// Freier Titel: gibt es [title] schon (Groß-/Kleinschreibung egal), dann „Titel (2)“, „Titel (3)“ …
String freierTitel(String title, Iterable<String> vorhandene) {
  final belegt = {for (final t in vorhandene) t.trim().toLowerCase()};
  final base = title.trim();
  if (!belegt.contains(base.toLowerCase())) return base;
  for (var n = 2; ; n++) {
    final suffix = ' ($n)';
    final t =
        '${fitUtf8(base, RezeptGrenzen.titelBytes - suffix.length).trim()}$suffix';
    if (!belegt.contains(t.toLowerCase())) return t;
  }
}

/// Gibt es ein Rezept dieses Titels schon (Groß-/Kleinschreibung und Leerzeichen am Rand egal)?
bool titelVorhanden(String title, Iterable<String> vorhandene) {
  final t = title.trim().toLowerCase();
  return vorhandene.any((v) => v.trim().toLowerCase() == t);
}

/// Rezept aus einer Datei als **neues** Rezept: neue [id], `rev` 0 (= neu anlegen, nie
/// überschreiben), freier Titel.
Recipe alsNeuesRezept(
  Recipe r, {
  required String id,
  required Iterable<String> vorhandeneTitel,
  DateTime? jetzt,
}) => Recipe(
  id: id,
  rev: 0,
  updated: (jetzt ?? DateTime.now()).toUtc(),
  title: freierTitel(r.title, vorhandeneTitel),
  servings: r.servings,
  photo: r.photo,
  tags: r.tags,
  steps: r.steps,
);

/// Programme, auf die das Rezept verweist, die es in [bekannte] nicht gibt – je Schritt (ab 1).
List<int> schritteMitUnbekanntemProgramm(Recipe r, Iterable<String> bekannte) {
  final ids = bekannte.toSet();
  return [
    for (final (n, s) in r.steps.indexed)
      if (s.machine?.programId case final id? when !ids.contains(id)) n + 1,
  ];
}
