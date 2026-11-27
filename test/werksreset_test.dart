// Werksreset mit „Alles löschen“ (Fähigkeit reset.wipe, Firmware ≥ 0.6.1) – vor Weitergabe/Verkauf.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruehrlink/app.dart';
import 'package:ruehrlink/core/storage/app_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Zurücksetzen bietet „auch Rezepte löschen“ an', (tester) async {
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
    await tester.pump(const Duration(seconds: 1));

    final kachel = find.text('Rührlink zurücksetzen');
    await tester.scrollUntilVisible(
      kachel,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(kachel);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Zurücksetzen'), findsOneWidget);
    expect(
      find.textContaining('Deine Rezepte bleiben erhalten'),
      findsOneWidget,
    );
    await tester.tap(
      find.text('Auch Rezepte und Fotos auf dem Rührlink löschen'),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Alles löschen'), findsOneWidget);
    expect(find.textContaining('wie neu'), findsOneWidget);

    await tester.tap(find.text('Abbrechen'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Alles löschen'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
