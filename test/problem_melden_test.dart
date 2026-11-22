// Mehr → „Problem melden“ gegen die simulierte Brücke (Demo-Modus).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruehrlink/app.dart';
import 'package:ruehrlink/core/storage/app_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('zeigt den Bericht vor dem Senden, im Demo-Modus ohne Box-Log', (
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
    await tester.tap(find.text('Problem melden'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4));

    expect(find.text('Box-Log nicht verfügbar – Demo-Modus.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Waage zeigt nichts an');
    await tester.pump();
    await tester.tap(find.text('Das wird mitgeschickt'));
    await tester.pump(const Duration(milliseconds: 500));
    final report = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data!;
    expect(report, contains('Waage zeigt nichts an'));
    expect(report, contains('Demo-Modus (kein Rührlink)'));
    expect(report, contains('== App-Ereignisse'));
    expect(tester.takeException(), isNull);

    // Baum abbauen, damit die Timer der simulierten Brücke enden.
    await tester.pumpWidget(const SizedBox());
  });
}
