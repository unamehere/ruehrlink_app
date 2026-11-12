// Einrichtung einmal komplett gegen den Provisioning-Fake durchlaufen.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freikoch/app.dart';
import 'package:freikoch/core/storage/app_storage.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Willkommen bis Fertig, danach die Tabs', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
        child: const FreikochApp(),
      ),
    );
    await tester.pump();

    Future<void> tapAndWait(Finder f, [int ms = 500]) async {
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pump(); // Klick verarbeiten, nächsten Schritt aufbauen
      await tester.pump(Duration(milliseconds: ms));
      await tester.pump(const Duration(milliseconds: 300)); // Übergang
    }

    expect(find.text('Willkommen bei Freikoch'), findsOneWidget);
    await tapAndWait(find.text("Los geht's"), 2000);

    // Brücke per Bluetooth (Fake) und Code vom Etikett.
    await tapAndWait(find.text('Freikoch-98C0'));
    await tester.enterText(find.byType(TextField), '1234');
    await tapAndWait(find.text('Verbinden'), 1000);

    // WLAN wählen und Passwort.
    await tester.pump(const Duration(seconds: 2));
    await tapAndWait(find.text('Zuhause'));
    await tester.enterText(find.byType(TextField), 'geheim');
    await tapAndWait(find.text('Verbinden'), 4000);

    // Maschine koppeln (Demo-Gerät ist sofort verbunden).
    expect(find.text('Maschine koppeln'), findsOneWidget);
    await tapAndWait(find.text('Ich habe auf Verbinden gedrückt'), 1500);

    expect(find.text('Fertig!'), findsOneWidget);
    await tapAndWait(find.text('Zur App'));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(prefs.getBool('setupDone'), isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
