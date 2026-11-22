// „Maschine neu koppeln“ (F18) gegen die simulierte Brücke.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/app.dart';
import 'package:ruehrlink/core/api/bridge_api.dart';
import 'package:ruehrlink/core/api/fake_bridge_api.dart';
import 'package:ruehrlink/core/models/models.dart';
import 'package:ruehrlink/core/storage/app_storage.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FakeBridgeApi.repairMachine', () {
    test('vergisst die Kopplung, Onboarding koppelt wieder', () async {
      final api = FakeBridgeApi(latency: Duration.zero);
      addTearDown(api.close);
      expect((await api.info()).has('machine.repair'), isTrue);
      expect((await api.info()).appliance!.paired, isTrue);

      await api.repairMachine();
      final info = await api.info();
      expect(info.appliance!.paired, isFalse);
      expect(info.appliance!.connected, isFalse);
      expect(info.readyCaps, isNull);

      await api.onboardMachine();
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      final after = await api.info();
      expect(after.appliance!.paired, isTrue);
      expect(after.appliance!.connected, isTrue);
    });

    test('während die Maschine arbeitet: busy', () async {
      final api = FakeBridgeApi(
        latency: Duration.zero,
        knobDelay: const Duration(milliseconds: 1),
      );
      addTearDown(api.close);
      await api.sendProgram(
        const MachineSettings(temperature: 0, time: 60, speed: 6),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        api.repairMachine,
        throwsA(
          isA<BridgeException>().having((e) => e.code, 'code', 'busy'),
        ),
      );
    });
  });

  test('ohne Fähigkeit machine.repair (Firmware 0.4.0) kein Eintrag', () {
    final info = BridgeInfo.fromJson({
      'id': '98C0',
      'name': 'Rührlink',
      'fw': '0.4.0',
      'api': 1,
      'features': ['machine', 'machine.onboard'],
    });
    expect(info.has('machine.repair'), isFalse);
  });

  testWidgets('Mehr → Maschine neu koppeln → Kopplung wie in der Einrichtung', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
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
    await tester.pump();
    await tester.tap(find.text('Mehr'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    final tile = find.text('Maschine neu koppeln');
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Maschine neu koppeln?'), findsOneWidget);

    // Abbrechen ändert nichts.
    await tester.tap(find.text('Abbrechen'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Maschine neu koppeln?'), findsNothing);

    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Neu koppeln'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));

    // Derselbe Schritt wie in der Einrichtung.
    final start = find.text('Ich habe auf Verbinden gedrückt');
    expect(start, findsOneWidget);
    await tester.ensureVisible(start);
    await tester.tap(start);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Maschine neu gekoppelt'), findsOneWidget);
    expect(start, findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
