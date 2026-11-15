// Assistenten-Ablauf gegen die simulierte Brücke: Kachel → Fragen → Ergebnis → Starten.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruehrlink/app.dart';
import 'package:ruehrlink/core/storage/app_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _start(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'setupDone': true});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
      child: const RuehrlinkApp(),
    ),
  );
  // Simulierte Brücke antwortet nach 250 ms; ihr Takt läuft weiter, daher kein pumpAndSettle.
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Kachel in die Bildschirmmitte scrollen (nicht unter die Navigationsleiste) und antippen.
Future<void> _tapMitte(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    // Kochen-Tab: Liste baut Kacheln erst beim Scrollen
    await tester.scrollUntilVisible(
      f,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
  await tester.pump();
  await tester.tap(f);
  await _pumpFrames(tester);
}

Future<void> _close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  for (final (name, size) in [
    ('Handy hochkant', const Size(390, 844)),
    ('Tablet quer', const Size(1280, 800)),
  ]) {
    testWidgets('$name: Dinkelteig durchklicken und starten', (tester) async {
      await _start(tester, size);
      await _tapMitte(tester, find.text('Brot & Hefeteig'));

      expect(find.text('Welches Mehl nimmst du?'), findsOneWidget);
      await _tapMitte(tester, find.text('Dinkel 630'));
      expect(find.text('Wie viel Mehl?'), findsOneWidget);
      // Rest mit Vorschlägen
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Weiter'));
        await _pumpFrames(tester);
      }

      expect(find.text('Zutaten'), findsOneWidget);
      expect(find.text('Nachkneten'), findsOneWidget);
      expect(find.text('300 g'), findsOneWidget); // 60 % Wasser von 500 g
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Starten'));
      await tester.pump(const Duration(seconds: 1));
      await _pumpFrames(tester);
      // zurück auf dem Kochen-Tab, Programm läuft (oben – Assistenten stehen unter den Programmen)
      expect(find.text('Zutaten'), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, 5000));
      await _pumpFrames(tester);
      expect(find.textContaining('Brotteig Dinkel 630'), findsWidgets);
      await _close(tester);
    });
  }

  testWidgets('Tipp auf den Tab Kochen schließt den Assistenten', (
    tester,
  ) async {
    await _start(tester, const Size(390, 844));
    await _tapMitte(tester, find.text('Brot & Hefeteig'));
    await _tapMitte(tester, find.text('Dinkel 630'));
    expect(find.text('Wie viel Mehl?'), findsOneWidget);
    await tester.tap(find.text('Kochen').last);
    await tester.pump(const Duration(seconds: 1)); // Schließ-Animation
    await _pumpFrames(tester);
    expect(find.text('Wie viel Mehl?'), findsNothing);
    expect(find.text('Brot & Hefeteig'), findsWidgets);
    await _close(tester);
  });

  testWidgets('Zurück führt zur vorigen Frage', (tester) async {
    await _start(tester, const Size(390, 844));
    await _tapMitte(tester, find.text('Eischnee'));
    await _tapMitte(tester, find.text('6 Eiweiß'));
    expect(find.text('Wie fest soll er werden?'), findsOneWidget);
    await tester.tap(find.byTooltip('Zurück'));
    await _pumpFrames(tester);
    expect(find.text('Wie viele Eiweiß?'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('Temperatur-Vorschläge im Maschinen-Tab (F19)', (tester) async {
    await _start(tester, const Size(390, 844));
    await tester.tap(find.text('Maschine'));
    await tester.pump(const Duration(seconds: 1));
    final knopf = find.byTooltip('Temperatur-Vorschläge');
    await tester.scrollUntilVisible(
      knopf,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(knopf);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Anbraten 180 °C'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('180 °C'), findsWidgets);
    await _close(tester);
  });
}
