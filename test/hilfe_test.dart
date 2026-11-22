// Hilfe-Knöpfe: Fenster öffnen nur auf Tipp, alle Themen bauen ohne Überlauf, Bildanleitung blättert.
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruehrlink/app.dart';
import 'package:ruehrlink/core/storage/app_storage.dart';
import 'package:ruehrlink/features/einrichtung/maschine_koppeln_anleitung.dart';
import 'package:ruehrlink/features/hilfe/hilfe_themen.dart';
import 'package:ruehrlink/l10n/l10n.dart';
import 'package:ruehrlink/ui/hilfe_knopf.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themen = <String, HilfeThema>{
  'Rezepte': hilfeRezepte,
  'Editor': hilfeEditor,
  'Bluetooth': hilfeEinrichtungBluetooth,
  'WLAN': hilfeEinrichtungWlan,
  'Maschine koppeln': hilfeMaschineKoppeln,
  'Kopplung bestätigen': hilfeKopplungBestaetigen,
  'Maschine': hilfeMaschine,
  'Waage': hilfeWaage,
  'Programme': hilfeProgramme,
  'Kochmodus': hilfeKochmodus,
  'Update': hilfeUpdate,
  'Verbindung': hilfeVerbindung,
};

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('de'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  home: home,
);

void _handy(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Knopf öffnet das Fenster mit Titel und Text', (tester) async {
    _handy(tester);
    await tester.pumpWidget(
      _app(Scaffold(appBar: AppBar(actions: const [HilfeKnopf(hilfeWaage)]))),
    );
    // Nie von selbst offen.
    expect(find.text('Tara'), findsNothing);

    await tester.tap(find.byTooltip('Hilfe'));
    await tester.pumpAndSettle();
    expect(find.text('Waage'), findsOneWidget);
    expect(find.text('Tara'), findsOneWidget);
    expect(find.textContaining('aktuelle Gewicht auf null'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final MapEntry(key: name, value: thema) in _themen.entries) {
    testWidgets('$name: Fenster ohne Überlauf', (tester) async {
      _handy(tester);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => HilfeFenster(hilfe: thema(context.l10n)),
            ),
          ),
        ),
      );
      final hilfe = thema(
        AppLocalizations.of(tester.element(find.byType(HilfeFenster))),
      );
      expect(find.text(hilfe.titel), findsOneWidget);
      expect(hilfe.eintraege.length, inInclusiveRange(2, 6));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Maschine koppeln: Knopf im Fenster öffnet die Bildanleitung', (
    tester,
  ) async {
    _handy(tester);
    await tester.pumpWidget(
      _app(
        Scaffold(
          appBar: AppBar(actions: const [HilfeKnopf(hilfeMaschineKoppeln)]),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Hilfe'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text("So geht's an der Maschine"));
    await tester.tap(find.text("So geht's an der Maschine"));
    await tester.pumpAndSettle();
    expect(find.byType(MaschineKoppelnAnleitung), findsOneWidget);
    expect(find.text('Bild 1 von 6'), findsOneWidget);
  });

  testWidgets('Bildanleitung: blättern bis „Fertig“, dann zu', (tester) async {
    _handy(tester);
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => zeigeMaschineKoppelnAnleitung(context),
              child: const Text('öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();

    for (var i = 1; i < maschineKoppelnBilder.length; i++) {
      expect(find.text('Bild $i von 6'), findsOneWidget);
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Bild 6 von 6'), findsOneWidget);
    expect(find.textContaining('SSID: KENWOOD'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(find.byType(MaschineKoppelnAnleitung), findsNothing);
  });

  test('Fotos der Anleitung liegen klein im Projekt', () {
    for (final pfad in maschineKoppelnBilder) {
      final f = File(pfad);
      expect(f.existsSync(), isTrue, reason: pfad);
      expect(f.lengthSync(), lessThan(150 * 1024), reason: pfad);
    }
  });

  testWidgets('Maschinen-Tab: Hilfe in der App-Leiste', (tester) async {
    _handy(tester);
    SharedPreferences.setMockInitialValues({'setupDone': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
        child: const RuehrlinkApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Maschine'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byTooltip('Hilfe').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Maschine steuern'), findsOneWidget);
    expect(find.text('Rührintervall'), findsWidgets);
    expect(tester.takeException(), isNull);

    // Simulierte Brücke abbauen, damit ihre Timer enden.
    await tester.pumpWidget(const SizedBox());
  });
}
