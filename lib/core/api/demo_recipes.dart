import '../models/json.dart';

/// Beispielrezepte für den Demo-Modus – so, wie sie auf einer Brücke liegen würden.
///
/// Das sind Daten, keine Oberflächentexte (daher nicht in `app_de.arb`). Ohne Fotos: die
/// App zeigt dann eine Illustration passend zum Titel. Maschinenwerte nutzen die Stufen der
/// Demo-Maschine (`FakeBridgeApi.demoSpeeds`, wie KCL95): 1–4 Rührintervall, 5 = min … 12 = max.
///
/// Zutaten stehen bei den Schritten; die Gesamtliste oben (`ingredients`) zählt die App daraus
/// zusammen und schreibt sie beim Speichern mit.
List<Json> demoRecipes() => [
  _recipe(
    n: 1,
    title: 'Dinkel-Brot',
    servings: 1,
    tags: ['Brot', 'Teig'],
    steps: [
      {
        'text': 'Mehl und Wasser in die Schüssel wiegen.',
        'tool': 'knethaken',
        'ingredients': [
          {'amount': 500, 'unit': 'g', 'name': 'Dinkelmehl 630'},
          {'amount': 330, 'unit': 'g', 'name': 'Wasser, lauwarm'},
        ],
      },
      {
        'text': 'Salz und Hefe dazugeben.',
        'ingredients': [
          {'amount': 10, 'unit': 'g', 'name': 'Salz'},
          {'amount': 7, 'unit': 'g', 'name': 'Trockenhefe'},
        ],
      },
      {
        'text': 'Langsam unterrühren.',
        'machine': {'temperature': 0, 'time': 60, 'speed': 5},
      },
      {
        'text': 'Zu einem glatten Teig kneten.',
        'machine': {'temperature': 0, 'time': 240, 'speed': 6},
      },
      {
        'text':
            'Abgedeckt 1 Stunde gehen lassen, formen und bei 230 °C '
            'etwa 40 Minuten backen.',
      },
    ],
  ),
  _recipe(
    n: 2,
    title: 'Pfannkuchen',
    servings: 4,
    tags: ['Süß', 'Schnell'],
    steps: [
      {
        'text': 'Mehl und Milch in die Schüssel geben.',
        'tool': 'schneebesen',
        'ingredients': [
          {'amount': 250, 'unit': 'g', 'name': 'Weizenmehl'},
          {'amount': 500, 'unit': 'g', 'name': 'Milch'},
        ],
      },
      {
        'text': 'Eier und Salz dazugeben.',
        'ingredients': [
          {'amount': 3, 'unit': '', 'name': 'Eier'},
          {'amount': 0, 'unit': '', 'name': 'Prise Salz'},
        ],
      },
      {
        'text': 'Glatt rühren.',
        'machine': {'temperature': 0, 'time': 60, 'speed': 8},
      },
      {
        'text':
            '20 Minuten quellen lassen, dann in einer heißen Pfanne mit '
            'etwas Butter dünn ausbacken.',
      },
    ],
  ),
  _recipe(
    n: 3,
    title: 'Risotto mit Parmesan',
    servings: 4,
    tags: ['Herzhaft', 'Warm'],
    steps: [
      {
        'text': 'Zwiebel fein würfeln, mit dem Öl anbraten.',
        'tool': 'kochRuehrelement',
        'ingredients': [
          {'amount': 100, 'unit': 'g', 'name': 'Zwiebel'},
          {'amount': 10, 'unit': 'g', 'name': 'Olivenöl'},
        ],
        'machine': {'temperature': 140, 'time': 180, 'speed': 1},
      },
      {
        'text': 'Reis hinzufügen und glasig dünsten.',
        'ingredients': [
          {'amount': 300, 'unit': 'g', 'name': 'Risottoreis'},
        ],
        'machine': {'temperature': 140, 'time': 120, 'speed': 1},
      },
      {
        'text': 'Brühe dazugießen und garen, bis der Reis bissfest ist.',
        'ingredients': [
          {'amount': 900, 'unit': 'g', 'name': 'Gemüsebrühe, heiß'},
        ],
        'machine': {'temperature': 100, 'time': 1080, 'speed': 3},
      },
      {
        'text': 'Parmesan und Butter unterrühren, abschmecken.',
        'ingredients': [
          {'amount': 60, 'unit': 'g', 'name': 'Parmesan'},
          {'amount': 30, 'unit': 'g', 'name': 'Butter'},
        ],
      },
    ],
  ),
  _recipe(
    n: 4,
    title: 'Baiser',
    servings: 20,
    tags: ['Süß', 'Backen'],
    steps: [
      {
        'text': 'Eiweiß und Salz in die saubere, fettfreie Schüssel geben, steif schlagen.',
        'tool': 'schneebesen',
        'ingredients': [
          {'amount': 4, 'unit': '', 'name': 'Eiweiß'},
          {'amount': 0, 'unit': '', 'name': 'Prise Salz'},
        ],
        'machine': {'temperature': 0, 'time': 90, 'speed': 12},
      },
      {
        'text': 'Zucker langsam einrieseln lassen und weiterschlagen.',
        'ingredients': [
          {'amount': 200, 'unit': 'g', 'name': 'Zucker'},
        ],
        'machine': {'temperature': 0, 'time': 120, 'speed': 11},
      },
      {
        'text':
            'Tupfen aufs Blech spritzen und bei 100 °C etwa 90 Minuten '
            'trocknen lassen.',
      },
    ],
  ),
];

Json _recipe({
  required int n,
  required String title,
  required int servings,
  required List<String> tags,
  required List<Json> steps,
}) => {
  'id': '4f1c2a8e-0d1b-4c6e-9a51-6d0b1e7f2a0$n',
  'rev': n,
  'updated': '2026-11-14T08:00:00Z',
  'title': title,
  'servings': servings,
  'photo': null,
  'tags': tags,
  'steps': steps,
};
