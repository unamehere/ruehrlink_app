import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ruehrlink/ui/icons/ruehr_icon.dart';

// Nur zum Ansehen: flutter test --update-goldens test/ruehr_icon_preview_test.dart
void main() {
  testWidgets('Rühr-Symbol Vorschau', (tester) async {
    await tester.binding.setSurfaceSize(const Size(560, 200));
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Color(0xFFFFFFFF),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RuehrIcon(size: 192, color: Color(0xFF24262B)),
              ColoredBox(
                color: Color(0xFF1E1F23),
                child: RuehrIcon(size: 96, color: Color(0xFFE8E8EA)),
              ),
              RuehrIcon(size: 48, color: Color(0xFF24262B)),
              RuehrIcon(size: 24, color: Color(0xFF24262B)),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(ColoredBox).first,
      matchesGoldenFile('goldens/ruehr_icon.png'),
    );
  });
}
