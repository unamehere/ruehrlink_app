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
import 'package:ruehrlink/features/rezepte/recipe_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

Recipe _recipe(String id, {int rev = 0, String title = 'Test'}) => Recipe(
  id: id,
  rev: rev,
  updated: DateTime.utc(2026, 11, 15),
  title: title,
  servings: 2,
  ingredients: const [Ingredient(amount: 250, unit: 'g', name: 'Mehl')],
  steps: const [
    RecipeStep(
      text: 'Wiegen',
      weigh: WeighTarget(target: 250, unit: 'g'),
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

        // Schritt 1: Wiegen – Platzhalter mit skalierter Zielmenge
        await tester.tap(find.text('Weiter'));
        await settle(tester);
        expect(find.text('315 g abwiegen'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // bis zum Maschinenschritt (Schritt 4)
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Weiter'));
          await settle(tester);
        }
        expect(find.text('An die Maschine senden'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }

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
      await close(tester);
    });
  });
}
