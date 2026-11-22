// „Automatisch zur nächsten Zutat“: Die Waage meldet erst, wenn das Gewicht ruhig im Zielbereich liegt.
import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruehrlink/core/api/bridge_providers.dart';
import 'package:ruehrlink/core/models/models.dart';
import 'package:ruehrlink/core/storage/app_storage.dart';
import 'package:ruehrlink/features/waage/scale.dart';
import 'package:ruehrlink/features/waage/scale_sheet.dart';
import 'package:ruehrlink/features/waage/scale_view.dart';
import 'package:ruehrlink/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StreamController<ScaleReading> waage;
  late int erreicht, ruhig;

  Future<void> starten(WidgetTester tester) async {
    waage = StreamController<ScaleReading>.broadcast();
    erreicht = 0;
    ruhig = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scaleProvider.overrideWith((ref) => waage.stream),
          applianceStatusProvider.overrideWith(
            (ref) => Stream.value(
              ApplianceStatus.disconnected.copyWith(connected: true),
            ),
          ),
          bridgeInfoProvider.overrideWith(
            (ref) => Completer<BridgeInfo>().future,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ScaleView(
              target: 100,
              onReached: () => erreicht++,
              onSettled: () => ruhig++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> wiegen(WidgetTester tester, double g) async {
    waage.add(ScaleReading(net: g, at: DateTime.now()));
    await tester.pump();
    await tester.pump();
  }

  Future<void> ende(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await waage.close();
  }

  testWidgets('meldet „ruhig“ erst nach der Wartezeit im Zielbereich', (
    tester,
  ) async {
    await starten(tester);
    await wiegen(tester, 100);
    expect(erreicht, 1);
    expect(ruhig, 0);
    await tester.pump(scaleSettleTime - const Duration(milliseconds: 500));
    await wiegen(tester, 100);
    expect(ruhig, 0);
    await tester.pump(const Duration(milliseconds: 600));
    expect(ruhig, 1);
    // nur einmal
    await tester.pump(scaleSettleTime * 2);
    expect(ruhig, 1);
    await ende(tester);
  });

  testWidgets('verlässt das Gewicht den Zielbereich, beginnt die Zeit neu', (
    tester,
  ) async {
    await starten(tester);
    await wiegen(tester, 100);
    await tester.pump(const Duration(seconds: 2));
    await wiegen(tester, 50); // wieder zu wenig, z. B. Löffel herausgenommen
    await tester.pump(const Duration(seconds: 1));
    expect(ruhig, 0);
    await wiegen(tester, 100);
    await tester.pump(const Duration(seconds: 2));
    expect(ruhig, 0);
    await tester.pump(const Duration(milliseconds: 600));
    expect(ruhig, 1);
    await ende(tester);
  });

  testWidgets('Einstellung ist ab Werk aus und wird gespeichert', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
    );
    addTearDown(c.dispose);
    expect(c.read(weighAutoNextProvider), isFalse);
    await c.read(weighAutoNextProvider.notifier).set(true);
    expect(c.read(weighAutoNextProvider), isTrue);
    expect(AppStorage(prefs).weighAutoNext, isTrue);
  });
}
