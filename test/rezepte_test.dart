import 'dart:async';
// Rezepte: Abgleich mit der Brücke (Revisionen, If-Match, Löschungen), Hilfen, Bildschirme.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruehrlink/app.dart';
import 'package:ruehrlink/core/api/bridge_providers.dart';
import 'package:ruehrlink/core/api/fake_bridge_api.dart';
import 'package:ruehrlink/core/models/models.dart';
import 'package:ruehrlink/core/storage/app_storage.dart';
import 'package:ruehrlink/core/storage/recipe_store.dart';
import 'package:ruehrlink/features/kochen/programs.dart';
import 'package:ruehrlink/features/rezepte/recipe_library.dart';
import 'package:ruehrlink/features/rezepte/rezept_datei.dart';
import 'package:ruehrlink/features/rezepte/rezept_teilen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Recipe _recipe(String id, {int rev = 0, String title = 'Test'}) => Recipe(
  id: id,
  rev: rev,
  updated: DateTime.utc(2026, 11, 15),
  title: title,
  servings: 2,
  steps: const [
    RecipeStep(
      text: 'Wiegen',
      ingredients: [Ingredient(amount: 250, unit: 'g', name: 'Mehl')],
    ),
  ],
);

void main() {
  group('Hilfen', () {
    test('Mengen runden und skalieren', () {
      expect(formatAmount(0), '');
      expect(formatAmount(312.5), '315');
      expect(formatAmount(10.5), '11');
      expect(formatAmount(4.5), '4,5');
      expect(formatAmount(7), '7');
      expect(scaleAmount(250, 4, 6), 375);
      expect(
        ingredientText(
          const Ingredient(amount: 500, unit: 'g', name: 'Mehl'),
          1.5,
        ),
        '750 g Mehl',
      );
      expect(
        ingredientText(
          const Ingredient(amount: 0, unit: '', name: 'Prise Salz'),
          2,
        ),
        'Prise Salz',
      );
    });

    test('UTF-8 kürzen zerschneidet keine Zeichen', () {
      expect(fitUtf8('Brötchen', 3), 'Br');
      expect(fitUtf8('Brötchen', 4), 'Brö');
      expect(utf8.encode(fitUtf8('ä' * 40, 31)).length, lessThanOrEqualTo(31));
    });

    test('ID und Prüfsumme passen zur Brücke', () {
      final id = newRecipeId();
      expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-')));
      expect(id.length, 36);
      expect(
        sha256Hex(Uint8List.fromList(utf8.encode('abc'))),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('Rezept-JSON wie in api.md', () {
      final r = Recipe.fromJson(
        jsonDecode('''
{"v":1,"id":"a","rev":7,"updated":"2026-11-12T10:00:00Z","title":"Brot","servings":4,
 "photo":null,"tags":["Brot"],"ingredients":[{"amount":500,"unit":"g","name":"Mehl"}],
 "steps":[{"text":"Wiegen","weigh":{"target":500,"unit":"g"}},
          {"text":"Kneten","machine":{"programId":"dinkelteig"}},
          {"text":"Rühren","machine":{"temperature":0,"time":60,"speed":2}}]}''')
            as Json,
      );
      expect(r.steps[1].machine!.programId, 'dinkelteig');
      expect(r.steps[2].machine!.settings!.time, 60);
      final again = Recipe.fromJson(jsonDecode(jsonEncode(r.toJson())) as Json);
      expect(again.toJson(), r.toJson());
    });
  });

  group('Abgleich', () {
    late FakeBridgeApi api;
    late MemoryRecipeStore store;
    late ProviderContainer c;

    Future<ProviderContainer> make({CachedLibrary? cached}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      api = FakeBridgeApi(latency: Duration.zero);
      store = MemoryRecipeStore();
      if (cached != null) store.libraries['demo'] = cached;
      final container = ProviderContainer(
        overrides: [
          appStorageProvider.overrideWithValue(AppStorage(prefs)),
          bridgeApiProvider.overrideWithValue(api),
          recipeStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(() {
        container.dispose();
        api.close();
      });
      container.listen(recipeLibraryProvider, (_, _) {});
      await container.read(recipeLibraryProvider.notifier).sync();
      return container;
    }

    test('holt die Bibliothek und legt eine Kopie ab', () async {
      c = await make();
      final lib = c.read(recipeLibraryProvider);
      expect(lib.recipes.length, 4);
      expect(lib.rev, 4);
      expect(lib.offline, isFalse);
      expect(store.libraries['demo']!.rev, 4);
    });

    test('speichert neu, erkennt Konflikte, löscht', () async {
      c = await make();
      final library = c.read(recipeLibraryProvider.notifier);

      final saved = await library.save(_recipe('neu-1'));
      expect(saved, isA<RecipeWritten>());
      await library.sync();
      expect(c.read(recipeLibraryProvider).recipes['neu-1']!.rev, 5);
      expect(c.read(recipeLibraryProvider).rev, 5);

      // Ein anderes Handy ändert dasselbe Rezept …
      await api.putRecipe(_recipe('neu-1', rev: 5, title: 'Anders'));
      // … unseres hat noch Revision 5 → Konflikt statt Überschreiben.
      final conflict = await library.save(_recipe('neu-1', rev: 5));
      expect(conflict, isA<RecipeConflict>());
      expect((conflict as RecipeConflict).currentRev, 6);
      await library.sync();
      expect(c.read(recipeLibraryProvider).recipes['neu-1']!.title, 'Anders');

      // „Meine Fassung speichern“ = mit der aktuellen Revision.
      final forced = await library.save(_recipe('neu-1', rev: 6));
      expect(forced, isA<RecipeWritten>());

      final current = c.read(recipeLibraryProvider).recipes['neu-1']!;
      final deleted = await library.delete(current);
      expect(deleted, isA<RecipeWritten>());
      await library.sync();
      expect(
        c.read(recipeLibraryProvider).recipes.containsKey('neu-1'),
        isFalse,
      );

      // Ein Handy mit älterem Stand erfährt die Löschung über `since`.
      final changes = await api.recipeChanges(5);
      expect(changes.deleted, contains('neu-1'));
    });

    test('Neu speichern, das es schon gibt → Konflikt', () async {
      c = await make();
      final library = c.read(recipeLibraryProvider.notifier);
      final existing = c.read(recipeLibraryProvider).sorted.first;
      final r = await library.save(existing.copyWith(rev: 0));
      expect(r, isA<RecipeConflict>());
    });

    test('Kopie neuer als die Brücke → alles neu holen', () async {
      c = await make(
        cached: CachedLibrary(rev: 99, recipes: [_recipe('alt', rev: 99)]),
      );
      final lib = c.read(recipeLibraryProvider);
      expect(lib.rev, 4);
      expect(lib.recipes.containsKey('alt'), isFalse);
      expect(lib.recipes.length, 4);
    });

    test('Foto wird hochgeladen und zwischengespeichert', () async {
      c = await make();
      final bytes = Uint8List.fromList([1, 2, 3]);
      final sha = await c
          .read(recipeLibraryProvider.notifier)
          .uploadPhoto(bytes);
      expect(await api.media(sha), bytes);
      expect(store.media[sha], bytes);
    });
  });

  group('F20: neues Rezept bleibt da', () {
    late _GateApi api;
    late MemoryRecipeStore store;
    late ProviderContainer c;

    Future<void> make() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      api = _GateApi();
      store = MemoryRecipeStore();
      c = ProviderContainer(
        overrides: [
          appStorageProvider.overrideWithValue(AppStorage(prefs)),
          bridgeApiProvider.overrideWithValue(api),
          recipeStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(() {
        c.dispose();
        api.close();
      });
      c.listen(recipeLibraryProvider, (_, _) {});
      await c.read(recipeLibraryProvider.notifier).sync();
    }

    test(
      'Abgleich-Antwort von vor dem Speichern entfernt es nicht (since=0)',
      () async {
        await make();
        // Frische Box ohne Rezepte → die App fragt immer mit since=0.
        api.empty = true;
        final library = c.read(recipeLibraryProvider.notifier);
        await library.sync();
        expect(c.read(recipeLibraryProvider).rev, 0);

        // Ein Abgleich läuft (z. B. vom Start), seine Antwort ist schon unterwegs …
        final gate = api.gate = Completer();
        final running = library.sync();
        // … währenddessen wird ein neues Rezept gespeichert.
        final saved = await library.save(_recipe('neu-f20'));
        expect(saved, isA<RecipeWritten>());
        var missing = false;
        c.listen(recipeLibraryProvider, (_, s) {
          if (!s.recipes.containsKey('neu-f20')) missing = true;
        });
        api.empty = false;
        gate.complete();
        await running;
        await library.sync();
        expect(missing, isFalse);
        expect(c.read(recipeLibraryProvider).recipes['neu-f20'], isNotNull);
      },
    );

    test('nach dem Speichern sofort in der lokalen Kopie', () async {
      await make();
      await c.read(recipeLibraryProvider.notifier).save(_recipe('neu-kopie'));
      await Future<void>.delayed(Duration.zero);
      expect(
        store.libraries['demo']!.recipes.map((r) => r.id),
        contains('neu-kopie'),
      );
    });

    test('Rezept, das der Abgleich nicht kennt, einzeln nachladen', () async {
      await make();
      final library = c.read(recipeLibraryProvider.notifier);
      api.empty = true; // Abgleich liefert es (noch) nicht
      await api.putRecipe(_recipe('direkt'));
      await library.sync();
      expect(c.read(recipeLibraryProvider).recipes['direkt'], isNull);
      final r = await library.fetch('direkt');
      expect(r?.title, 'Test');
      expect(c.read(recipeLibraryProvider).recipes['direkt'], isNotNull);
      expect(await library.fetch('gibt-es-nicht'), isNull);
    });

    test('ein unlesbares Rezept bricht den Abgleich nicht ab', () {
      final changes = RecipeChanges.fromJson({
        'rev': 3,
        'changed': [
          {'id': 'a', 'rev': 1, 'title': 'Gut', 'photo': 12},
          {'rev': 2, 'title': 'Ohne ID'},
          'Unsinn',
        ],
      });
      expect(changes.changed.map((r) => r.id), ['a']);
      expect(changes.changed.single.photo, isNull);
    });
  });

  group('Bildschirme', () {
    // Simulierte Brücke tickt weiter, daher kein pumpAndSettle; zwei Bilder für Übergänge.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> open(WidgetTester tester, Size size) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'setupDone': true});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStorageProvider.overrideWithValue(AppStorage(prefs)),
            recipeStoreProvider.overrideWithValue(MemoryRecipeStore()),
          ],
          child: const RuehrlinkApp(),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Rezepte').first);
      await settle(tester);
      await settle(tester); // Bibliothek geladen, Button eingeblendet
    }

    Future<void> close(WidgetTester tester) =>
        tester.pumpWidget(const SizedBox());

    for (final (name, size) in [
      ('Tablet quer', const Size(1280, 800)),
      ('Handy hochkant', const Size(390, 844)),
      ('Handy quer', const Size(844, 390)),
    ]) {
      testWidgets('$name: Liste, Rezept, Kochmodus ohne Überlauf', (
        tester,
      ) async {
        await open(tester, size);
        expect(tester.takeException(), isNull);
        expect(find.text('Pfannkuchen'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Pfannkuchen'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        // nicht unter dem schwebenden Button antippen
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -80));
        await tester.pump();
        await tester.tap(find.text('Pfannkuchen'));
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('250 g Weizenmehl'), findsOneWidget);
        await tester.ensureVisible(find.byTooltip('Mehr Portionen'));
        await tester.pump();
        await tester.tap(find.byTooltip('Mehr Portionen'));
        await tester.pump();
        expect(find.text('315 g Weizenmehl'), findsOneWidget);

        await tester.tap(find.text('Jetzt kochen'));
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Bereitstellen'), findsOneWidget);
        expect(find.text('315 g Weizenmehl'), findsOneWidget);

        // Schritt 1: Zutaten des Schritts, Waage mit skalierter Zielmenge
        await tester.tap(find.text('Weiter'));
        await settle(tester);
        // Werkzeugwechsel als eigene Seite vor dem Schritt
        expect(find.text('Schneebesen einsetzen'), findsOneWidget);
        expect(find.text('Erledigt, weiter'), findsOneWidget);
        await tester.tap(find.text('Erledigt, weiter'));
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('315 g Weizenmehl abwiegen'), findsOneWidget);
        expect(find.text('Zutat 1 von 2'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Hauptknopf führt erst zur nächsten Zutat, nicht zum nächsten Schritt (F23)
        expect(find.text('Weiter'), findsNothing);
        await tester.tap(find.text('Nächste Zutat'));
        await settle(tester);
        expect(find.text('625 g Milch abwiegen'), findsOneWidget);
        expect(find.text('Zutat 2 von 2'), findsOneWidget);
        // zurück zur schon gewogenen ersten Zutat und wieder vor
        await tester.tap(find.byTooltip('Vorige Zutat'));
        await settle(tester);
        expect(find.text('Zutat 1 von 2'), findsOneWidget);
        await tester.tap(find.byTooltip('Nächste Zutat'));
        await settle(tester);
        expect(find.text('Zutat 2 von 2'), findsOneWidget);
        expect(find.text('Schritt 1 von 4'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // bis zum Maschinenschritt (Schritt 3); Schritt 2 (Eier, Salz) führt jetzt auch
        // durch die Zutaten ohne Waage
        for (var i = 0; i < 2; i++) {
          if (i == 1) {
            expect(find.textContaining('Eier zugeben'), findsOneWidget);
            expect(
              find.text('Ohne Waage – zugeben und weiter.'),
              findsOneWidget,
            );
          }
          while (find.text('Nächste Zutat').evaluate().isNotEmpty) {
            await tester.tap(find.text('Nächste Zutat'));
            await settle(tester);
          }
          await tester.tap(find.text('Weiter'));
          await settle(tester);
        }
        expect(find.text('An die Maschine senden'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }

    testWidgets(
      'Kochmodus: Wegwischen mit offenen Zutaten wird dezent angemerkt',
      (tester) async {
        await open(tester, const Size(390, 844));
        await tester.scrollUntilVisible(
          find.text('Pfannkuchen'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -80));
        await tester.pump();
        await tester.tap(find.text('Pfannkuchen'));
        await settle(tester);
        await tester.tap(find.text('Jetzt kochen'));
        await settle(tester);
        await tester.tap(find.text('Weiter'));
        await settle(tester);
        await tester.tap(find.text('Erledigt, weiter'));
        await settle(tester);
        expect(find.text('Zutat 1 von 2'), findsOneWidget);

        // Wischen bleibt frei – kein Dialog, nur ein Hinweis oben
        Future<void> wischen(double dx) async {
          await tester.fling(find.byType(PageView), Offset(dx, 0), 1500);
          await settle(tester);
        }

        await wischen(-300);
        expect(find.text('Schritt 2 von 4'), findsOneWidget);
        expect(find.text('Schritt 1: 2 Zutaten offen'), findsOneWidget);
        await wischen(300);
        expect(find.text('Schritt 1: 2 Zutaten offen'), findsNothing);
        expect(find.text('Zutat 1 von 2'), findsOneWidget);

        // Mehl mit dem Hauptknopf abhaken, dann wegwischen: 1 Zutat offen
        await tester.tap(find.text('Nächste Zutat'));
        await settle(tester);
        expect(find.text('Zutat 2 von 2'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
        // Liste: zurück zum Mehl antippen und wieder weg – weiter geht's bei der ersten offenen
        final mehl = find.widgetWithText(InkWell, '250 g Weizenmehl');
        await tester.ensureVisible(mehl);
        await tester.pump();
        await tester.tap(mehl);
        await settle(tester);
        expect(find.text('Zutat 1 von 2'), findsOneWidget);
        await wischen(-300);
        expect(find.text('Schritt 1: 1 Zutat offen'), findsOneWidget);
        await tester.tap(find.text('Schritt 1: 1 Zutat offen'));
        await settle(tester);
        expect(find.text('Zutat 2 von 2'), findsOneWidget);
        expect(find.text('500 g Milch abwiegen'), findsOneWidget);

        // Kreis vor der Zutat antippen = von Hand abhaken (z. B. ohne Waage abgewogen)
        final kreis = find.byTooltip('Abhaken');
        await tester.ensureVisible(kreis);
        await tester.pump();
        await tester.tap(kreis);
        await settle(tester);
        expect(find.byTooltip('Abhaken'), findsNothing);
        await wischen(-300);
        expect(find.textContaining('Zutat offen'), findsNothing);
        await wischen(300);

        // letzte Zutat: Hauptknopf heißt wieder „Weiter“ und blättert
        await tester.tap(find.text('Weiter'));
        await settle(tester);
        expect(find.text('Schritt 2 von 4'), findsOneWidget);
        expect(find.textContaining('Zutaten offen'), findsNothing);
        expect(find.textContaining('Zutat offen'), findsNothing);
        expect(tester.takeException(), isNull);
        await close(tester);
      },
    );

    testWidgets('Maschinenschritt mit Phasen: Kochmodus und Editor', (
      tester,
    ) async {
      await open(tester, const Size(390, 844));
      const id = '11111111-2222-4333-8444-555555555555';
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      unawaited(
        container
            .read(recipeLibraryProvider.notifier)
            .save(
              Recipe(
                id: id,
                rev: 0,
                updated: DateTime.utc(2026, 11, 22),
                title: 'Strudelteig',
                servings: 1,
                steps: const [
                  RecipeStep(
                    text: 'Unterrühren, dann kneten',
                    machine: StepMachine.settings(
                      MachineSettings(temperature: 0, time: 60, speed: 5),
                      then: [
                        MachineSettings(temperature: 0, time: 300, speed: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      );
      await settle(tester);
      await settle(tester);

      // Kochmodus: Phasenliste, Gesamtzeit, ein Programm mit zwei Schritten
      container.read(routerProvider).go('/rezepte/$id/kochen');
      await settle(tester);
      await tester.tap(find.text('Weiter'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('2 Phasen · 6:00 gesamt'), findsOneWidget);
      expect(find.text('1:00 Stufe min → 5:00 Stufe 1'), findsOneWidget);
      await tester.ensureVisible(find.text('An die Maschine senden'));
      await tester.pump();
      await tester.tap(find.text('An die Maschine senden'));
      await settle(tester);
      final seq = container.read(sequenceProvider).value!;
      expect(seq.of, 2);
      expect(seq.step, 1);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Kochmodus beenden'));
      await settle(tester);
      unawaited(container.read(sequenceControllerProvider).abort());
      await settle(tester);

      // Editor: Phase 2 sichtbar, „Phase anhängen“ übernimmt die letzten Werte
      container.read(routerProvider).go('/rezepte/$id/bearbeiten');
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Phase 2 – direkt im Anschluss'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Phase anhängen'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Phase anhängen'));
      await tester.pump();
      expect(find.text('Phase 3 – direkt im Anschluss'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Speichern'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Speichern'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      final gespeichert = container.read(recipeLibraryProvider).recipes[id]!;
      expect(gespeichert.steps.single.machine!.phasen, const [
        MachineSettings(temperature: 0, time: 60, speed: 5),
        MachineSettings(temperature: 0, time: 300, speed: 6),
        MachineSettings(temperature: 0, time: 300, speed: 6),
      ]);
      await close(tester);
    });

    testWidgets('Rezept von der echten Box (15.11., altes Format) öffnen', (
      tester,
    ) async {
      await open(tester, const Size(390, 844));
      // genau so lag es auf der Box (GET /recipes/c2dc3faa-…)
      final box = Recipe.fromJson({
        'v': 1,
        'id': 'c2dc3faa-def6-427d-818d-1723beabf97b',
        'rev': 0,
        'updated': '2026-11-15T13:54:04Z',
        'title': 'Risotto',
        'servings': 4,
        'photo': null,
        'tags': ['Reisgericht'],
        'ingredients': [
          {'amount': 100, 'unit': 'g', 'name': 'Zwiebel'},
          {'amount': 10, 'unit': 'g', 'name': 'Öl'},
        ],
        'steps': [
          {
            'text': 'Glasig anschwitzen',
            'machine': {'temperature': 120, 'time': 180, 'speed': 1},
          },
          {
            'text': 'Reis hinzufügen',
            'weigh': {'target': 320, 'unit': 'g'},
          },
        ],
      });
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      // nicht awaiten: die Demo-Brücke antwortet über Timer, die erst settle() weiterlaufen lässt
      unawaited(container.read(recipeLibraryProvider.notifier).save(box));
      await settle(tester);
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text('Risotto'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Risotto'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Glasig anschwitzen'), findsOneWidget);
      await tester.tap(find.text('Jetzt kochen'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    testWidgets('Rezept-Datei: Vorschau, übernehmen, Namenskollision', (
      tester,
    ) async {
      await open(tester, const Size(390, 844));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      final pfannkuchen = container
          .read(recipeLibraryProvider)
          .recipes
          .values
          .firstWhere((r) => r.title == 'Pfannkuchen');
      container
          .read(rezeptEingangProvider.notifier)
          .set(
            RezeptEingang(
              name: 'Pfannkuchen.rlrezept',
              bytes: RezeptDatei.schreiben(pfannkuchen, const {}),
            ),
          );
      container.read(routerProvider).go(rezeptUebernehmenPfad);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Rezept übernehmen'), findsOneWidget);
      expect(find.textContaining('„Pfannkuchen (2)“'), findsOneWidget);
      await tester.tap(find.text('In meine Rezepte übernehmen'));
      await settle(tester);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Pfannkuchen (2)'), findsWidgets);
      expect(find.byTooltip('Teilen'), findsOneWidget);
      final lib = container.read(recipeLibraryProvider);
      expect(
        lib.recipes.values
            .where((r) => r.title.startsWith('Pfannkuchen'))
            .length,
        2,
      );

      // kaputte Datei → Meldung statt Absturz
      container
          .read(rezeptEingangProvider.notifier)
          .set(
            RezeptEingang(
              name: 'x.rlrezept',
              bytes: Uint8List.fromList([1, 2]),
            ),
          );
      container.read(routerProvider).go(rezeptUebernehmenPfad);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'Diese Datei ist kein Rührlink-Rezept oder sie ist beschädigt.',
        ),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('Menü: Grundrezepte hinzufügen (ohne Duplikate)', (
      tester,
    ) async {
      await open(tester, const Size(390, 844));
      await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton));
      await settle(tester);
      expect(find.text('Rezept-Datei öffnen'), findsOneWidget);
      await tester.tap(find.text('Grundrezepte hinzufügen'));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.textContaining('hinzugefügt').evaluate().isNotEmpty) break;
      }
      expect(tester.takeException(), isNull);
      // „Baiser“ gibt es in der Demo schon
      expect(find.text('9 Grundrezepte hinzugefügt.'), findsOneWidget);
      await settle(tester); // Abgleich danach
      await close(tester);
    });

    testWidgets('Editor: neues Rezept anlegen', (tester) async {
      await open(tester, const Size(390, 844));
      await tester.tap(find.text('Neues Rezept'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.widgetWithText(TextField, 'Titel'),
        'Mein Brot',
      );
      await tester.scrollUntilVisible(
        find.text('Speichern'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Speichern'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      // Nach dem Speichern: Rezeptseite
      expect(find.text('Mein Brot'), findsWidgets);
      // zurück zur Liste und wieder öffnen (Fehler 15.11.: ließ sich nicht wieder öffnen)

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Mein Brot'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Mein Brot'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Bearbeiten'), findsOneWidget);
      await close(tester);
    });
  });
}

/// Demo-Brücke, deren Abgleich-Antworten sich zurückhalten lassen (F20).
class _GateApi extends FakeBridgeApi {
  _GateApi() : super(latency: Duration.zero);

  /// Antwortet wie eine leere Box (rev 0).
  bool empty = false;

  /// Solange gesetzt: Antwort wird beim Aufruf festgehalten und erst danach ausgeliefert.
  Completer<void>? gate;

  @override
  Future<RecipeChanges> recipeChanges(int since) async {
    final snapshot = empty
        ? const RecipeChanges(rev: 0)
        : await super.recipeChanges(since);
    final g = gate;
    if (g != null) {
      gate = null;
      await g.future;
    }
    return snapshot;
  }
}
