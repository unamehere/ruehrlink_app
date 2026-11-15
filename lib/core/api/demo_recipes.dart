import '../models/json.dart';

/// Beispielrezepte für den Demo-Modus – so, wie sie auf einer Brücke liegen würden.
///
/// Das sind Daten, keine Oberflächentexte (daher nicht in `app_de.arb`). Ohne Fotos: die
/// App zeigt dann eine Illustration passend zum Titel. Maschinenwerte nutzen die Stufen der
/// Demo-Maschine (`FakeBridgeApi.demoSpeeds`, wie KCL95): 1–4 Rührintervall, 5 = min … 12 = max.
List<Json> demoRecipes() => [
  {
    'id': '4f1c2a8e-0d1b-4c6e-9a51-6d0b1e7f2a01',
    'rev': 1,
    'updated': '2026-11-14T08:00:00Z',
    'title': 'Dinkel-Brot',
    'servings': 1,
    'photo': null,
    'tags': ['Brot', 'Teig'],
    'ingredients': [
      {'amount': 500, 'unit': 'g', 'name': 'Dinkelmehl 630'},
      {'amount': 330, 'unit': 'g', 'name': 'Wasser, lauwarm'},
      {'amount': 10, 'unit': 'g', 'name': 'Salz'},
      {'amount': 7, 'unit': 'g', 'name': 'Trockenhefe'},
    ],
    'steps': [
      {
        'text': 'Knethaken einsetzen. Mehl in die Schüssel wiegen.',
        'weigh': {'target': 500, 'unit': 'g'},
      },
      {
        'text': 'Wasser dazuwiegen.',
        'weigh': {'target': 330, 'unit': 'g'},
      },
      {'text': 'Salz und Hefe dazugeben.'},
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
  },
  {
    'id': '4f1c2a8e-0d1b-4c6e-9a51-6d0b1e7f2a02',
    'rev': 2,
    'updated': '2026-11-14T08:00:00Z',
    'title': 'Pfannkuchen',
    'servings': 4,
    'photo': null,
    'tags': ['Süß', 'Schnell'],
    'ingredients': [
      {'amount': 250, 'unit': 'g', 'name': 'Weizenmehl'},
      {'amount': 500, 'unit': 'ml', 'name': 'Milch'},
      {'amount': 3, 'unit': '', 'name': 'Eier'},
      {'amount': 0, 'unit': '', 'name': 'Prise Salz'},
    ],
    'steps': [
      {
        'text': 'Rührbesen einsetzen. Mehl in die Schüssel wiegen.',
        'weigh': {'target': 250, 'unit': 'g'},
      },
      {
        'text': 'Milch dazuwiegen.',
        'weigh': {'target': 500, 'unit': 'g'},
      },
      {'text': 'Eier und Salz dazugeben.'},
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
  },
  {
    'id': '4f1c2a8e-0d1b-4c6e-9a51-6d0b1e7f2a03',
    'rev': 3,
    'updated': '2026-11-14T08:00:00Z',
    'title': 'Risotto mit Parmesan',
    'servings': 4,
    'photo': null,
    'tags': ['Herzhaft', 'Warm'],
    'ingredients': [
      {'amount': 1, 'unit': '', 'name': 'Zwiebel'},
      {'amount': 2, 'unit': 'EL', 'name': 'Olivenöl'},
      {'amount': 300, 'unit': 'g', 'name': 'Risottoreis'},
      {'amount': 900, 'unit': 'ml', 'name': 'Gemüsebrühe, heiß'},
      {'amount': 60, 'unit': 'g', 'name': 'Parmesan'},
      {'amount': 30, 'unit': 'g', 'name': 'Butter'},
    ],
    'steps': [
      {
        'text':
            'Rührelement einsetzen. Zwiebel fein würfeln, mit dem Öl '
            'in die Schüssel geben.',
      },
      {
        'text': 'Zwiebel andünsten.',
        'machine': {'temperature': 140, 'time': 180, 'speed': 1},
      },
      {
        'text': 'Reis dazuwiegen.',
        'weigh': {'target': 300, 'unit': 'g'},
      },
      {
        'text': 'Reis glasig dünsten.',
        'machine': {'temperature': 140, 'time': 120, 'speed': 1},
      },
      {
        'text': 'Brühe dazugießen.',
        'weigh': {'target': 900, 'unit': 'g'},
      },
      {
        'text': 'Garen, bis der Reis bissfest ist.',
        'machine': {'temperature': 100, 'time': 1080, 'speed': 3},
      },
      {'text': 'Parmesan und Butter unterrühren, abschmecken.'},
    ],
  },
  {
    'id': '4f1c2a8e-0d1b-4c6e-9a51-6d0b1e7f2a04',
    'rev': 4,
    'updated': '2026-11-14T08:00:00Z',
    'title': 'Baiser',
    'servings': 20,
    'photo': null,
    'tags': ['Süß', 'Backen'],
    'ingredients': [
      {'amount': 4, 'unit': '', 'name': 'Eiweiß'},
      {'amount': 200, 'unit': 'g', 'name': 'Zucker'},
      {'amount': 0, 'unit': '', 'name': 'Prise Salz'},
    ],
    'steps': [
      {
        'text':
            'Rührbesen einsetzen. Eiweiß und Salz in die saubere, '
            'fettfreie Schüssel geben.',
      },
      {
        'text': 'Steif schlagen.',
        'machine': {'temperature': 0, 'time': 90, 'speed': 12},
      },
      {
        'text': 'Zucker abwiegen.',
        'weigh': {'target': 200, 'unit': 'g'},
      },
      {
        'text': 'Zucker langsam einrieseln lassen und weiterschlagen.',
        'machine': {'temperature': 0, 'time': 120, 'speed': 11},
      },
      {
        'text':
            'Tupfen aufs Blech spritzen und bei 100 °C etwa 90 Minuten '
            'trocknen lassen.',
      },
    ],
  },
];
