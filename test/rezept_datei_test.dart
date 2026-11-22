// Rezept-Datei (.rlrezept): Lesen/Schreiben, Grenzen, Übernahme als neues Rezept, Grundrezepte.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/core/api/bridge_api.dart';
import 'package:ruehrlink/core/api/bridge_providers.dart';
import 'package:ruehrlink/core/api/fake_bridge_api.dart';
import 'package:ruehrlink/core/models/models.dart';
import 'package:ruehrlink/core/storage/app_storage.dart';
import 'package:ruehrlink/core/storage/recipe_store.dart';
import 'package:ruehrlink/features/rezepte/recipe_library.dart';
import 'package:ruehrlink/features/rezepte/rezept_datei.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kleinstes gültiges WebP-Gerüst (RIFF….WEBP) – reicht für die Prüfung der Kennung.
Uint8List _webp([int fill = 1]) => Uint8List.fromList([
  ...ascii.encode('RIFF'),
  20,
  0,
  0,
  0,
  ...ascii.encode('WEBP'),
  ...List.filled(20, fill),
]);

Recipe _recipe({
  String title = 'Pizzateig',
  String? photo,
  String? stepPhoto,
}) => Recipe(
  id: 'abc-1',
  rev: 7,
  updated: DateTime.utc(2026, 11, 20),
  title: title,
  servings: 4,
  photo: photo,
  tags: const ['Teig'],
  steps: [
    RecipeStep(
      text: 'Mehl wiegen',
      photo: stepPhoto,
      tool: Werkzeug.knethaken,
      ingredients: const [
        Ingredient(amount: 500, unit: 'g', name: 'Mehl'),
        Ingredient(amount: 300, unit: 'ml', name: 'Milch'),
      ],
    ),
    const RecipeStep(
      text: 'Kneten',
      machine: StepMachine.settings(
        MachineSettings(temperature: 0, time: 300, speed: 6),
      ),
    ),
    const RecipeStep(
      text: 'Programm',
      machine: StepMachine.program('dinkelteig'),
    ),
    // Maschinenschritt mit zwei Phasen (1 min Stufe min → 5 min Stufe 1)
    const RecipeStep(
      text: 'Unterrühren, dann kneten',
      machine: StepMachine.settings(
        MachineSettings(temperature: 0, time: 60, speed: 1),
        then: [MachineSettings(temperature: 0, time: 300, speed: 2)],
      ),
    ),
  ],
);

Json _json(Uint8List bytes) => jsonDecode(utf8.decode(bytes)) as Json;
Uint8List _bytes(Object json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

class _OfflineApi extends FakeBridgeApi {
  _OfflineApi() : super(latency: Duration.zero);
  bool offline = false;

  void _check() {
    if (offline) throw const BridgeException(BridgeErrorKind.unreachable);
  }

  @override
  Future<RecipeChanges> recipeChanges(int since) {
    _check();
    return super.recipeChanges(since);
  }

  @override
  Future<RecipeWriteResult> putRecipe(Recipe recipe) {
    _check();
    return super.putRecipe(recipe);
  }

  @override
  Future<void> putMedia(String sha256, Uint8List webp) {
    _check();
    return super.putMedia(sha256, webp);
  }
}

void main() {
  group('Datei lesen und schreiben', () {
    test('Rundreise mit Fotos', () {
      final photo = _webp(1), stepPhoto = _webp(2);
      final shaA = sha256Hex(photo), shaB = sha256Hex(stepPhoto);
      final r = _recipe(photo: shaA, stepPhoto: shaB);
      final bytes = RezeptDatei.schreiben(r, {shaA: photo, shaB: stepPhoto});
      final json = _json(bytes);
      expect(json['schema'], 1);
      expect(json['title'], 'Pizzateig');
      expect((json['media'] as Map).keys, containsAll([shaA, shaB]));
      // Gesamtliste wie bei der API dabei
      expect((json['ingredients'] as List).length, 2);

      final d = RezeptDatei.lesen(bytes);
      expect(d.recipe.toJson(), r.toJson());
      // Phasen kommen mit (Feld `then` im `machine`-Objekt)
      expect(((json['steps'] as List).last as Map)['machine'], {
        'temperature': 0,
        'time': 60,
        'speed': 1,
        'then': [
          {'temperature': 0, 'time': 300, 'speed': 2},
        ],
      });
      expect(d.recipe.steps.last.machine!.phasen.length, 2);
      expect(d.recipe.steps.last.machine!.gesamtS, 360);
      expect(d.photos[shaA], photo);
      expect(d.photos[shaB], stepPhoto);
      expect(d.hinweise.keine, isTrue);
      expect(d.schema, 1);
    });

    test('fehlendes Foto: Verweis beim Schreiben weg', () {
      final r = _recipe(photo: 'a' * 64);
      final d = RezeptDatei.lesen(RezeptDatei.schreiben(r, const {}));
      expect(d.recipe.photo, isNull);
      expect(
        _json(RezeptDatei.schreiben(r, const {})).containsKey('media'),
        isFalse,
      );
      expect(d.hinweise.fehlendeFotos, 0);
    });

    test('beschädigtes oder falsches Foto wird weggelassen, Rezept bleibt', () {
      final photo = _webp();
      final sha = sha256Hex(photo);
      final json = _json(
        RezeptDatei.schreiben(_recipe(photo: sha), {sha: photo}),
      );
      // Prüfsumme passt nicht mehr
      json['media'] = {sha: base64Encode(_webp(9))};
      final d = RezeptDatei.lesen(_bytes(json));
      expect(d.recipe.photo, isNull);
      expect(d.photos, isEmpty);
      expect(d.hinweise.fehlendeFotos, 1);
      // kein Base64
      json['media'] = {sha: '%%%'};
      expect(RezeptDatei.lesen(_bytes(json)).hinweise.fehlendeFotos, 1);
    });

    test('altes Format (ohne schema, Zutaten oben, weigh) wird gelesen', () {
      final d = RezeptDatei.lesen(
        _bytes({
          'id': 'x',
          'rev': 3,
          'title': 'Brot',
          'servings': 2,
          'ingredients': [
            {'amount': 500, 'unit': 'g', 'name': 'Mehl'},
          ],
          'steps': [
            {
              'text': 'Wiegen',
              'weigh': {'target': 500, 'unit': 'g'},
            },
          ],
        }),
      );
      expect(d.schema, 1);
      expect(d.recipe.steps.single.ingredients.single.name, 'Mehl');
      expect(d.hinweise.keine, isTrue);
    });

    test(
      'neueres schema und unbekanntes Werkzeug: Schritt bleibt, Hinweis',
      () {
        final json = _json(RezeptDatei.schreiben(_recipe(), const {}));
        json['schema'] = 3;
        json['neuesFeld'] = {'x': 1};
        ((json['steps'] as List)[0] as Map)['tool'] = 'multizerkleinerer';
        final d = RezeptDatei.lesen(_bytes(json));
        expect(d.hinweise.neueresFormat, isTrue);
        expect(d.hinweise.unbekannteWerkzeuge, [1]);
        expect(d.recipe.steps.length, 4);
        expect(d.recipe.steps[0].tool, isNull);
        expect(d.recipe.steps[0].ingredients.length, 2);
      },
    );

    test('unbekanntes Programm wird erkannt', () {
      expect(schritteMitUnbekanntemProgramm(_recipe(), ['pizza']), [3]);
      expect(
        schritteMitUnbekanntemProgramm(_recipe(), ['dinkelteig']),
        isEmpty,
      );
    });

    test('kaputte Dateien → verständlicher Fehler', () {
      RezeptDateiFehler fehler(List<int> b) {
        try {
          RezeptDatei.lesen(b);
        } on RezeptDateiException catch (e) {
          return e.fehler;
        }
        fail('kein Fehler');
      }

      expect(fehler(const []), RezeptDateiFehler.leer);
      expect(
        fehler(utf8.encode('{"title": "Pizza", "steps": [')),
        RezeptDateiFehler.kaputt,
      );
      expect(fehler([0xff, 0xfe, 0x00, 0x01]), RezeptDateiFehler.kaputt);
      expect(fehler(utf8.encode('[1, 2, 3]')), RezeptDateiFehler.keinRezept);
      expect(
        fehler(utf8.encode('{"title": ""}')),
        RezeptDateiFehler.keinRezept,
      );
      expect(
        fehler(utf8.encode('{"name": "Pizza"}')),
        RezeptDateiFehler.keinRezept,
      );
      expect(
        fehler(Uint8List(RezeptGrenzen.dateiBytes + 1)),
        RezeptDateiFehler.zuGross,
      );
      // falsche Typen werden toleriert statt abzustürzen
      final d = RezeptDatei.lesen(
        _bytes({
          'title': 'Pizza',
          'servings': 'vier',
          'photo': 42,
          'tags': 'Teig',
          'steps': [
            'kein Schritt',
            {'text': 5, 'machine': 'an'},
          ],
        }),
      );
      expect(d.recipe.servings, 1);
      expect(d.recipe.photo, isNull);
      expect(d.recipe.steps.length, 1);
    });

    test('Grenzen der Brücke: Titel, Schritte, Portionen, Größe', () {
      final json = _json(RezeptDatei.schreiben(_recipe(), const {}));
      json['title'] = 'Ä' * 150; // 300 Byte
      json['servings'] = 5000;
      json['steps'] = [
        for (var i = 0; i < 250; i++) {'text': 'S$i'},
      ];
      final d = RezeptDatei.lesen(_bytes(json));
      expect(utf8.encode(d.recipe.title).length, lessThanOrEqualTo(200));
      expect(d.recipe.servings, 1000);
      expect(d.recipe.steps.length, 200);
      expect(d.hinweise.gekuerzt, isTrue);

      json['steps'] = [
        for (var i = 0; i < 100; i++) {'text': 'x' * 300},
      ];
      expect(
        () => RezeptDatei.lesen(_bytes(json)),
        throwsA(
          isA<RezeptDateiException>().having(
            (e) => e.fehler,
            'fehler',
            RezeptDateiFehler.rezeptZuGross,
          ),
        ),
      );
    });

    test('BOM am Anfang stört nicht', () {
      final b = RezeptDatei.schreiben(_recipe(), const {});
      expect(
        RezeptDatei.lesen([0xef, 0xbb, 0xbf, ...b]).recipe.title,
        'Pizzateig',
      );
    });
  });

  group('Namen', () {
    test('Dateiname gesäubert', () {
      expect(rezeptDateiName('Pizzateig'), 'Pizzateig.rlrezept');
      expect(
        rezeptDateiName('Omas "beste" Soße: 1/2 Rezept?'),
        'Omas beste Soße 1 2 Rezept.rlrezept',
      );
      expect(rezeptDateiName('  ..Brot..  '), 'Brot.rlrezept');
      expect(rezeptDateiName('***'), 'Rezept.rlrezept');
      expect(rezeptDateiName('Zeile\nzwei'), 'Zeile zwei.rlrezept');
      expect(
        utf8.encode(rezeptDateiName('ö' * 100)).length,
        lessThanOrEqualTo(80 + 9),
      );
    });

    test('Namenskollision → „(2)“, „(3)“', () {
      expect(freierTitel('Pizza', ['Brot']), 'Pizza');
      expect(freierTitel('Pizza', ['pizza ']), 'Pizza (2)');
      expect(freierTitel('Pizza', ['Pizza', 'Pizza (2)']), 'Pizza (3)');
      final lang = 'a' * 200;
      final t = freierTitel(lang, [lang]);
      expect(t.endsWith(' (2)'), isTrue);
      expect(utf8.encode(t).length, lessThanOrEqualTo(200));
    });

    test('als neues Rezept: neue ID, rev 0', () {
      final r = alsNeuesRezept(
        _recipe(),
        id: 'neu-1',
        vorhandeneTitel: ['Pizzateig'],
        jetzt: DateTime.utc(2026, 11, 22),
      );
      expect(r.id, 'neu-1');
      expect(r.rev, 0);
      expect(r.title, 'Pizzateig (2)');
      expect(r.steps.length, 4);
    });
  });

  group('Übernehmen', () {
    late _OfflineApi api;
    late ProviderContainer c;

    Future<void> make() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      api = _OfflineApi();
      c = ProviderContainer(
        overrides: [
          appStorageProvider.overrideWithValue(AppStorage(prefs)),
          bridgeApiProvider.overrideWithValue(api),
          recipeStoreProvider.overrideWithValue(MemoryRecipeStore()),
        ],
      );
      addTearDown(() {
        c.dispose();
        api.close();
      });
      c.listen(recipeLibraryProvider, (_, _) {});
      await c.read(recipeLibraryProvider.notifier).sync();
    }

    test('immer neu, nie überschreiben; Foto zuerst hochgeladen', () async {
      await make();
      final library = c.read(recipeLibraryProvider.notifier);
      final existing = c.read(recipeLibraryProvider).sorted.first;
      final photo = _webp();
      final sha = sha256Hex(photo);
      // Datei mit derselben ID und demselben Titel wie ein vorhandenes Rezept
      final datei = RezeptDatei.lesen(
        RezeptDatei.schreiben(existing.copyWith(photo: sha), {sha: photo}),
      );
      final r = await library.uebernehmen(datei);
      final lib = c.read(recipeLibraryProvider);
      expect(r.id, isNot(existing.id));
      expect(r.title, '${existing.title} (2)');
      expect(lib.recipes[existing.id]!.title, existing.title);
      expect(lib.recipes[r.id], isNotNull);
      expect(await api.media(sha), photo);
      expect(lib.recipes.length, 5);
    });

    test('offline: klare Ausnahme, nichts gespeichert', () async {
      await make();
      api.offline = true;
      final library = c.read(recipeLibraryProvider.notifier);
      final datei = RezeptDatei.lesen(
        RezeptDatei.schreiben(_recipe(), const {}),
      );
      await expectLater(
        library.uebernehmen(datei),
        throwsA(isA<BridgeException>()),
      );
      expect(c.read(recipeLibraryProvider).recipes.length, 4);
      // später klappt es mit derselben Datei
      api.offline = false;
      final r = await library.uebernehmen(datei);
      expect(r.title, 'Pizzateig');
    });

    test(
      'Grundrezepte: gültig, Werte im erlaubten Bereich, ohne Duplikate',
      () async {
        final files =
            Directory('assets/rezepte')
                .listSync()
                .whereType<File>()
                .where((f) => f.path.endsWith(rezeptDateiEndung))
                .toList()
              ..sort((a, b) => a.path.compareTo(b.path));
        expect(files.length, inInclusiveRange(8, 12));
        final caps = FakeBridgeApi.demoCaps; // Stufen wie KCL95
        final dateien = <RezeptDatei>[];
        for (final f in files) {
          final d = RezeptDatei.lesen(f.readAsBytesSync());
          final r = d.recipe;
          final name = f.path;
          expect(d.hinweise.keine, isTrue, reason: name);
          expect(r.tags, contains('Grundrezept'), reason: name);
          expect(r.steps, isNotEmpty, reason: name);
          expect(r.ingredients, isNotEmpty, reason: name);
          // gespeicherte Gesamtliste passt zu den Schritten
          final json = _json(f.readAsBytesSync());
          expect(
            jsonEncode(json['ingredients']),
            jsonEncode([for (final i in r.ingredients) i.toJson()]),
            reason: name,
          );
          for (final i in r.ingredients) {
            expect(recipeUnits, contains(i.unit), reason: '$name: ${i.name}');
          }
          expect(r.steps.first.tool, isNotNull, reason: name);
          Werkzeug? tool;
          for (final s in r.steps) {
            tool = s.tool ?? tool;
            final m = s.machine?.settings;
            if (s.machine != null) expect(m, isNotNull, reason: name);
            if (m == null) continue;
            expect(caps.speedOption(m.speed), isNotNull, reason: name);
            expect(m.time, inInclusiveRange(1, caps.timeMaxS), reason: name);
            expect(
              m.temperature == 0 ||
                  (m.temperature >= caps.tempMin &&
                      m.temperature <= caps.tempMax),
              isTrue,
              reason: name,
            );
            if (m.temperature > 0) {
              // Hitze nur mit dem Kochrührelement, und heiß nicht zu schnell
              expect(tool, Werkzeug.kochRuehrelement, reason: name);
              expect(caps.tooFastWhenHot(m.speed), isFalse, reason: name);
            }
          }
          dateien.add(d);
        }
        final titles = [for (final d in dateien) d.recipe.title];
        expect(titles.toSet().length, titles.length);

        // Hinzufügen: in der Demo gibt es „Baiser“ schon → übersprungen; zweites Mal nichts mehr.
        await make();
        final library = c.read(recipeLibraryProvider.notifier);
        final n = await library.grundrezepteHinzufuegen(dateien);
        expect(n, dateien.length - 1);
        expect(await library.grundrezepteHinzufuegen(dateien), 0);
        final lib = c.read(recipeLibraryProvider);
        expect(lib.recipes.values.where((r) => r.title == 'Baiser').length, 1);
        expect(
          lib.recipes.values
              .where((r) => r.tags.contains('Grundrezept'))
              .length,
          n,
        );
      },
    );

    test('Grundrezepte offline → Ausnahme', () async {
      await make();
      api.offline = true;
      final datei = RezeptDatei.lesen(
        RezeptDatei.schreiben(_recipe(), const {}),
      );
      await expectLater(
        c.read(recipeLibraryProvider.notifier).grundrezepteHinzufuegen([datei]),
        throwsA(isA<BridgeException>()),
      );
    });
  });
}
