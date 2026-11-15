import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/core/api/fake_bridge_api.dart';
import 'package:ruehrlink/core/models/models.dart';
import 'package:ruehrlink/features/waage/scale.dart';

void main() {
  group('Zielbereich', () {
    test('Toleranz 3 %, mindestens 2 g', () {
      expect(scaleTolerance(500), 15);
      expect(scaleTolerance(10), 2);
    });

    test('Zonen um 500 g', () {
      expect(scaleZone(100, 500), ScaleZone.below);
      expect(scaleZone(430, 500), ScaleZone.near);
      expect(scaleZone(486, 500), ScaleZone.onTarget);
      expect(scaleZone(514, 500), ScaleZone.onTarget);
      expect(scaleZone(516, 500), ScaleZone.over);
    });

    test('kleine Mengen: Salz 8 g', () {
      expect(scaleZone(6, 8), ScaleZone.onTarget);
      expect(scaleZone(11, 8), ScaleZone.over);
    });

    test('Ring bleibt bei zu viel voll', () {
      expect(scaleProgress(250, 500), 0.5);
      expect(scaleProgress(800, 500), 1.0);
      expect(scaleProgress(-5, 500), 0.0);
    });

    test('Zittern um 0 zeigt 0', () {
      expect(displayGrams(0.4), 0);
      expect(displayGrams(-0.3), 0);
      expect(displayGrams(41.6), 42);
    });
  });

  group('Demo-Waage', () {
    test('liefert Werte nach watch, Tara setzt auf 0', () async {
      final api = FakeBridgeApi(latency: Duration.zero);
      addTearDown(api.close); // Demo-Maschine ist von Anfang an verbunden

      final weights = <WeightEvent>[];
      final sub = api.events().listen((e) {
        if (e is WeightEvent) weights.add(e);
      });
      addTearDown(sub.cancel);

      await api.watchScale(seconds: 5);
      await Future<void>.delayed(const Duration(milliseconds: 550));
      expect(weights, isNotEmpty);
      expect(weights.last.grams, greaterThan(0));

      final before = weights.length;
      final tare = await api.tareScale();
      await Future<void>.delayed(Duration.zero); // Stream liefert asynchron
      expect(tare, greaterThan(0));
      expect(weights.skip(before).any((w) => w.grams == 0), isTrue);
    });
  });
}
