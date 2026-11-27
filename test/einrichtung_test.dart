// Einrichtung einmal komplett gegen den Provisioning-Fake durchlaufen.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/app.dart';
import 'package:ruehrlink/core/api/bridge_providers.dart';
import 'package:ruehrlink/core/api/fake_bridge_api.dart';
import 'package:ruehrlink/core/provisioning/bridge_provisioning.dart';
import 'package:ruehrlink/core/provisioning/fake_bridge_provisioning.dart';
import 'package:ruehrlink/core/storage/app_storage.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Willkommen bis Fertig, danach die Tabs', (tester) async {
    await _runSetup(tester, machinePaired: false);
  });

  // App neu installiert: Rührlink im WLAN, Maschine schon gekoppelt.
  testWidgets('Maschine schon gekoppelt: Schritt entfällt', (tester) async {
    await _runSetup(tester, machinePaired: true);
  });
}

Future<void> _runSetup(
  WidgetTester tester, {
  required bool machinePaired,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(prefs)),
        bridgeProvisioningProvider.overrideWithValue(FakeBridgeProvisioning()),
        bridgeApiProvider.overrideWith((ref) {
          final api = FakeBridgeApi(paired: machinePaired);
          ref.onDispose(api.close);
          return api;
        }),
      ],
      child: const RuehrlinkApp(),
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

  expect(find.text('Willkommen bei Rührlink'), findsOneWidget);
  await tapAndWait(find.text("Los geht's"), 2000);

  // Code vom Etikett (hier der QR-Inhalt abgetippt) → Brücke wird per
  // Bluetooth (Fake) gefunden und automatisch verbunden.
  await tester.enterText(
    find.byType(TextField),
    '{"ver":"v1","name":"Ruehrlink-98C0","pop":"abcde23456",'
    '"transport":"ble","security":2,"username":"ruehrlink"}',
  );
  await tapAndWait(find.text('Weiter'), 3000);

  // WLAN wählen und Passwort.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tapAndWait(find.text('Zuhause'));
  await tester.enterText(find.byType(TextField), 'geheim');
  await tapAndWait(find.text('Verbinden'), 4000);
  await tester.pump(const Duration(seconds: 1));

  if (machinePaired) {
    // Maschine schon gekoppelt: Schritt entfällt, „Fertig“ sagt warum.
    expect(find.text('Maschine koppeln'), findsNothing);
    expect(
      find.textContaining('schon mit dem Rührlink gekoppelt'),
      findsOneWidget,
    );
  } else {
    // Maschine koppeln (Demo-Gerät verbindet sich nach 2 s).
    expect(find.text('Maschine koppeln'), findsOneWidget);
    // Bildanleitung und Hilfe sind da, aber nur auf Tipp.
    expect(find.text("So geht's an der Maschine"), findsOneWidget);
    expect(find.byTooltip('Hilfe'), findsOneWidget);
    await tapAndWait(find.text('Ich habe auf Verbinden gedrückt'), 3000);
    expect(
      find.textContaining('schon mit dem Rührlink gekoppelt'),
      findsNothing,
    );
  }

  expect(find.text('Fertig!'), findsOneWidget);
  await tapAndWait(find.text('Zur App'));
  expect(find.byType(NavigationBar), findsOneWidget);
  expect(prefs.getBool('setupDone'), isTrue);
  expect(tester.takeException(), isNull);

  await tester.pumpWidget(const SizedBox());
}
