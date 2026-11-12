// Maschinen-Bildschirm gegen die simulierte Brücke, in Handy- und Tablet-Größe.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freikoch/app.dart';
import 'package:freikoch/core/storage/app_storage.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openMaschine(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'setupDone': true});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
      child: const FreikochApp(),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Maschine'));
  // Simulierte Brücke antwortet nach 250 ms; ihr Takt läuft weiter,
  // daher kein pumpAndSettle.
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

/// Baum abbauen, damit die Timer der simulierten Brücke enden.
Future<void> _close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  for (final (name, size) in [
    ('Tablet quer', const Size(1280, 800)),
    ('Handy hochkant', const Size(390, 844)),
    ('Handy quer', const Size(844, 390)),
  ]) {
    testWidgets('$name: rendert ohne Überlauf', (tester) async {
      await _openMaschine(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.text('Maschine verbunden'), findsOneWidget);
      expect(find.text('Stopp'), findsOneWidget);
      // Auf schmalen Bildschirmen liegen die Regler weiter unten.
      await tester.scrollUntilVisible(
        find.text('An Maschine senden'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await _close(tester);
    });
  }

  testWidgets('Tablet quer: Seitenleiste, Status links, Regler rechts', (
    tester,
  ) async {
    await _openMaschine(tester, const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    final band = tester.getCenter(find.text('Maschine verbunden'));
    final dial = tester.getCenter(find.text('Temperatur'));
    expect(dial.dx, greaterThan(band.dx));
    await _close(tester);
  });

  testWidgets('Stufe wählen und senden – Maschine bestätigt', (tester) async {
    await _openMaschine(tester, const Size(1280, 800));
    // Tippen auf die Beschriftung „max“ rastet den Stufenregler dort ein.
    await tester.tap(find.text('max'));
    await tester.pump();
    expect(find.text('max'), findsNWidgets(2)); // Skala + großes Label
    expect(find.text('Dauerstufen'), findsWidgets);
    await tester.tap(find.text('An Maschine senden'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Die Maschine hat die Werte übernommen.'), findsOneWidget);
    await _close(tester);
  });
}
