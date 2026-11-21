import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/core/models/models.dart';

void main() {
  group('Zutaten pro Schritt', () {
    test('Gesamtliste zählt gleiche Zutaten zusammen, Reihenfolge bleibt', () {
      const r = RecipeStep(
        text: 'a',
        ingredients: [
          Ingredient(amount: 100, unit: 'g', name: 'Zwiebel'),
          Ingredient(amount: 10, unit: 'g', name: 'Öl'),
        ],
      );
      const s = RecipeStep(
        text: 'b',
        ingredients: [
          Ingredient(amount: 5, unit: 'g', name: 'öl'),
          Ingredient(amount: 1, unit: 'EL', name: 'Öl'),
          Ingredient(amount: 0, unit: '', name: 'Prise Salz'),
        ],
      );
      final recipe = Recipe(
        id: 'x',
        rev: 0,
        updated: DateTime.utc(2026),
        title: 't',
        servings: 2,
        steps: const [r, s],
      );
      final all = recipe.ingredients;
      expect(
        [for (final i in all) '${i.amount} ${i.unit} ${i.name}'],
        ['100.0 g Zwiebel', '15.0 g Öl', '1.0 EL Öl', '0.0  Prise Salz'],
      );
      // wird mitgespeichert
      expect((recipe.toJson()['ingredients'] as List).length, 4);
    });

    test('Gramm erkennt g und kg, sonst nicht wiegbar', () {
      expect(const Ingredient(amount: 2, unit: 'kg', name: 'x').grams, 2000);
      expect(const Ingredient(amount: 200, unit: ' G ', name: 'x').grams, 200);
      expect(const Ingredient(amount: 200, unit: 'ml', name: 'Wasser').grams, 200);
      expect(const Ingredient(amount: 1, unit: 'l', name: 'Rapsöl').grams, closeTo(920, 0.01));
      expect(const Ingredient(amount: 100, unit: 'ml', name: 'Kölsch').grams, 100);
      expect(const Ingredient(amount: 1, unit: 'Prise', name: 'Salz').grams, null);
      expect(const Ingredient(amount: 0, unit: 'g', name: 'x').grams, null);
    });

    test('Umwandlung: übrige Zutaten landen im ersten Schritt', () {
      final r = Recipe.fromJson({
        'id': 'x',
        'rev': 1,
        'updated': '2026-11-15T00:00:00Z',
        'title': 't',
        'servings': 1,
        'ingredients': [
          {'amount': 1, 'unit': '', 'name': 'Zwiebel'},
          {'amount': 300, 'unit': 'g', 'name': 'Reis'},
        ],
        'steps': [
          {'text': 'Zwiebel würfeln.'},
          {
            'text': 'Reis dazuwiegen.',
            'weigh': {'target': 300, 'unit': 'g'},
          },
        ],
      });
      expect(r.steps[0].ingredients.single.name, 'Zwiebel');
      expect(r.steps[1].ingredients.single.name, 'Reis');
      expect(r.ingredients.length, 2);
    });

    test('Werkzeug wird gespeichert, unbekanntes ignoriert', () {
      final s = RecipeStep.fromJson({'text': 'a', 'tool': 'knethaken'});
      expect(s.tool, Werkzeug.knethaken);
      expect(s.toJson()['tool'], 'knethaken');
      expect(
        RecipeStep.fromJson({'text': 'a', 'tool': 'laserschwert'}).tool,
        null,
      );
    });
  });
}
