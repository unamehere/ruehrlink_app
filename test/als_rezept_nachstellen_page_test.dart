// Bildschirme: „Als Rezept speichern“ im Assistenten und „Noch nicht fertig?“ (Nachstellen)
// auf dem Kochen-Tab und im Kochmodus – gegen die simulierte Brücke.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruehrlink/app.dart';
import 'package:ruehrlink/core/api/bridge_api.dart';
import 'package:ruehrlink/core/api/bridge_providers.dart';
import 'package:ruehrlink/core/api/fake_bridge_api.dart';
import 'package:ruehrlink/core/models/models.dart';
import 'package:ruehrlink/core/storage/app_storage.dart';
import 'package:ruehrlink/core/storage/recipe_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simulierte Brücke, bei der das Speichern von Rezepten „nicht erreichbar“ sein kann.
class _Api extends FakeBridgeApi {
  bool speichernOffline = false;

  @override
  Future<RecipeWriteResult> putRecipe(Recipe recipe) {
    if (speichernOffline) {
      throw const BridgeException(BridgeErrorKind.unreachable);
    }
    return super.putRecipe(recipe);
  }
}

Future<_Api> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'setupDone': true});
  final prefs = await SharedPreferences.getInstance();
  final api = _Api();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(prefs)),
        bridgeApiProvider.overrideWithValue(api),
        recipeStoreProvider.overrideWithValue(MemoryRecipeStore()),
      ],
      child: const RuehrlinkApp(),
    ),
  );
  // Simulierte Brücke tickt weiter, daher kein pumpAndSettle.
  await _sekunden(tester, 2);
  return api;
}

Future<void> _sekunden(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tippe(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
  await tester.pump();
  await tester.tap(f);
  await _frames(tester);
}

/// Sahne-Assistent öffnen, Vorschlag übernehmen → Ergebnisseite.
Future<void> _sahneErgebnis(WidgetTester tester) async {
  await _tippe(
    tester,
    find.text('Menge wählen, starten – lieber kurz, nachschlagen geht immer.'),
  );
  await tester.tap(find.text('Weiter'));
  await _frames(tester);
  expect(find.text('Zutaten'), findsOneWidget);
}

/// Großer „Fertig!“-Hinweis (SequenceNudgeWatcher) wegklicken.
Future<void> _hinweisWeg(WidgetTester tester) async {
  final ok = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('OK'),
  );
  expect(ok, findsOneWidget);
  await tester.tap(ok);
  await _frames(tester);
}

Future<void> _ende(WidgetTester tester, FakeBridgeApi api) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1)); // offene Antworten der Brücke
  api.close();
}

void main() {
  testWidgets(
    'Assistent als Rezept speichern; nicht erreichbar → Dialog bleibt',
    (tester) async {
      final api = await _start(tester);
      await _sahneErgebnis(tester);

      await _tippe(tester, find.text('Als Rezept speichern'));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Meine Schlagsahne'),
        findsOneWidget,
      );

      // Rührlink nicht erreichbar: klare Meldung, Dialog und Titel bleiben
      api.speichernOffline = true;
      await tester.enterText(find.byType(TextField), 'Sahne für Kuchen');
      await tester.tap(find.text('Speichern'));
      await _frames(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Der Rührlink ist nicht erreichbar.'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Sahne für Kuchen'),
        findsOneWidget,
      );

      // Wieder da: speichern, Hinweis mit „Öffnen“
      api.speichernOffline = false;
      await tester.tap(find.text('Speichern'));
      await _sekunden(tester, 1);
      await _frames(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Als Rezept gespeichert.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Öffnen'));
      await _sekunden(tester, 2);
      expect(find.text('Sahne für Kuchen'), findsWidgets);
      expect(find.text('Jetzt kochen'), findsOneWidget);
      // Anschlagen → Schlagen läuft durch: ein Schritt mit zwei Phasen
      expect(find.text('Anschlagen, dann Schlagen'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _ende(tester, api);
    },
  );

  testWidgets('Kochen-Tab: nach dem Assistenten „Noch nicht fertig?“ → +30 s', (
    tester,
  ) async {
    final api = await _start(tester);
    await _sahneErgebnis(tester);
    await tester.tap(find.text('Starten'));
    await _sekunden(tester, 1);
    await _frames(tester);

    // Knopf (3 s) + 20 s anschlagen + 110 s schlagen
    await _sekunden(tester, 140);
    await _hinweisWeg(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, 5000));
    await _frames(tester);
    expect(find.text('Noch nicht fertig?'), findsOneWidget);
    expect(find.text('+30 s'), findsOneWidget);
    expect(find.text('+1 min'), findsOneWidget);

    await tester.tap(find.text('+30 s'));
    await _sekunden(tester, 1);
    expect(
      find.text(
        'Noch 30 s mit denselben Werten – Knopf an der Maschine drücken.',
      ),
      findsOneWidget,
    );
    expect(find.text('Noch nicht fertig?'), findsNothing);
    expect(find.text('Sahne 400 ml'), findsOneWidget); // gleiche Karte
    // ein einzelner Schritt: kein „Schritt 1 von 1“, nur die Phase
    expect(find.text('Schlagen'), findsOneWidget);
    expect(find.textContaining('Schritt 1 von 1'), findsNothing);

    // Läuft durch, danach wieder angeboten – weiter mit den kurzen Zeiten
    await _sekunden(tester, 40);
    await _hinweisWeg(tester);
    expect(find.text('+30 s'), findsOneWidget);
    // „OK“ schließt die Karte samt Angebot
    await tester.tap(find.text('OK'));
    await _frames(tester);
    expect(find.text('Noch nicht fertig?'), findsNothing);
    expect(tester.takeException(), isNull);
    await _ende(tester, api);
  });

  testWidgets(
    'Kochmodus: nach dem Schritt nachstellen, „Weiter“ geht normal weiter',
    (tester) async {
      final api = await _start(tester);
      final context = tester.element(find.byType(Scaffold).first);
      GoRouter.of(context)
          .go('/rezepte/4f1c2a8e-0d1b-4c6e-9a51-6d0b1e7f2a04/kochen'); // Baiser
      await _sekunden(tester, 2);
      await tester.tap(find.text('Weiter')); // Bereitstellen
      await _sekunden(tester, 2);
      await tester.tap(find.text('Erledigt, weiter')); // Schneebesen
      await _sekunden(tester, 2);
      expect(find.text('Schritt 1 von 3'), findsOneWidget);

      await _tippe(tester, find.text('An die Maschine senden'));
      await _sekunden(tester, 1);
      expect(find.text('Noch nicht fertig?'), findsNothing); // läuft noch
      await _sekunden(tester, 96); // Knopf + 90 s
      await _hinweisWeg(tester);

      // bleibt stehen (kein automatisches Weiterblättern) und bietet Nachstellen an
      await _sekunden(tester, 3);
      expect(find.text('Schritt 1 von 3'), findsOneWidget);
      expect(find.text('Noch nicht fertig?'), findsOneWidget);
      expect(find.text('+30 s'), findsOneWidget);
      expect(find.text('+1 min'), findsOneWidget);

      await _tippe(tester, find.text('+1 min'));
      await _sekunden(tester, 1);
      expect(find.text('Noch nicht fertig?'), findsNothing);
      expect(find.text('Programm abbrechen'), findsOneWidget); // läuft wieder
      await _sekunden(tester, 66);
      await _hinweisWeg(tester);
      expect(find.text('Noch nicht fertig?'), findsOneWidget);

      // Nicht aufdrängen: „Weiter“ geht normal zum nächsten Schritt (vorher die
      // Zutaten ohne Waage abhaken, die stehen jetzt auch in der Reihenfolge)
      while (find.text('Nächste Zutat').evaluate().isNotEmpty) {
        await tester.tap(find.text('Nächste Zutat'));
        await _sekunden(tester, 1);
      }
      await tester.tap(find.text('Weiter'));
      await _sekunden(tester, 2);
      expect(find.text('Schritt 2 von 3'), findsOneWidget);
      expect(find.text('Noch nicht fertig?'), findsNothing);
      expect(tester.takeException(), isNull);
      await _ende(tester, api);
    },
  );
}
