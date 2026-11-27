// Schriftgröße klein / mittel / groß: wird gespeichert und wirkt auf die Schrift.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruehrlink/core/storage/app_storage.dart';
import 'package:ruehrlink/ui/text_size.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Schriftgröße wirkt und bleibt gespeichert', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    late WidgetRef ref;
    double? scale;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
        child: MaterialApp(
          builder: (context, child) => AppTextScale(child: child!),
          home: Consumer(
            builder: (context, r, _) {
              ref = r;
              scale = MediaQuery.textScalerOf(context).scale(20);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(ref.read(textSizeProvider), TextSize.medium);
    expect(scale, 20);

    await ref.read(textSizeProvider.notifier).set(TextSize.small);
    await tester.pump();
    expect(scale, closeTo(17, 0.001));
    expect(prefs.getInt('textSize'), 0);

    await ref.read(textSizeProvider.notifier).set(TextSize.large);
    await tester.pump();
    expect(scale, closeTo(23, 0.001));
  });
}
