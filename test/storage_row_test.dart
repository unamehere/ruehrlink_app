// Speicheranzeige in Mehr → Verbindung.
import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruehrlink/app.dart';
import 'package:ruehrlink/core/models/models.dart';
import 'package:ruehrlink/core/storage/app_storage.dart';
import 'package:ruehrlink/features/mehr/storage_row.dart';
import 'package:ruehrlink/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(StorageInfo s) => MaterialApp(
  locale: const Locale('de'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: StorageRow(s)),
);

void main() {
  testWidgets('SD-Karte: Art, Belegung, kein Hinweis', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const StorageInfo(backend: 'sd', totalKB: 30720000, freeKB: 29696000),
      ),
    );
    await tester.pump();
    expect(find.text('Speicher · SD-Karte'), findsOneWidget);
    expect(find.text('1.000 MB von 30.000 MB belegt'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('fast voll'), findsNothing);
  });

  testWidgets('Flash fast voll: dezenter Hinweis', (tester) async {
    await tester.pumpWidget(
      _wrap(const StorageInfo(backend: 'flash', totalKB: 10240, freeKB: 512)),
    );
    await tester.pump();
    expect(find.text('Speicher · Interner Speicher'), findsOneWidget);
    expect(find.text('10 MB von 10 MB belegt'), findsOneWidget);
    expect(find.textContaining('fast voll'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.95, 0.001));
  });

  test('Anteil belegt', () {
    expect(
      StorageRow.usedFraction(
        const StorageInfo(backend: 'sd', totalKB: 0, freeKB: 0),
      ),
      0,
    );
    expect(
      StorageRow.usedFraction(
        const StorageInfo(backend: 'sd', totalKB: 100, freeKB: 10),
      ),
      closeTo(0.9, 0.001),
    );
  });

  test('ältere Firmware ohne storage', () {
    final info = BridgeInfo.fromJson({'id': 'X', 'name': 'R', 'fw': '0.2.0'});
    expect(info.storage, isNull);
  });

  testWidgets('Mehr → Verbindung zeigt den Speicher (Demo)', (tester) async {
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
    await tester.tap(find.text('Verbindung zum Rührlink'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Speicher · SD-Karte'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
