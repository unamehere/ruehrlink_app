import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Illustrationen für Zutaten und Programme.
///
/// Vorerst Platzhalter aus Microsoft Fluent Emoji 3D (MIT, siehe
/// `assets/illustrations/LICENSE-fluentui-emoji.txt` und `docs/illustrationen.md`).
/// Später ersetzt ein eigener Satz im Rührlink-Stil die Dateien – die Namen hier bleiben.
abstract final class Illustrations {
  static const _dir = 'assets/illustrations';

  /// Stichwort (klein, Teil des Zutatennamens) → Bild. Reihenfolge zählt: das erste Stichwort,
  /// das im Namen vorkommt, gewinnt („Eigelb“ vor „Ei“ wäre z. B. ein eigener Eintrag).
  static const _byKeyword = <(String, String)>[
    ('eischnee', 'egg'),
    ('mehl', 'sheaf_of_rice'),
    ('grieß', 'sheaf_of_rice'),
    ('hefe', 'bread'),
    ('brot', 'bread'),
    ('brötchen', 'baguette_bread'),
    ('baguette', 'baguette_bread'),
    ('brezel', 'pretzel'),
    ('fladen', 'flatbread'),
    ('pizza', 'pizza'),
    ('croissant', 'croissant'),
    ('pfannkuchen', 'pancakes'),
    ('crêpe', 'pancakes'),
    ('kuchen', 'shortcake'),
    ('torte', 'shortcake'),
    ('sahne', 'glass_of_milk'),
    ('milch', 'glass_of_milk'),
    ('joghurt', 'glass_of_milk'),
    ('quark', 'glass_of_milk'),
    ('butter', 'butter'),
    ('käse', 'cheese_wedge'),
    ('parmesan', 'cheese_wedge'),
    ('eiweiß', 'egg'),
    ('eigelb', 'egg'),
    ('eier', 'egg'),
    ('ei', 'egg'),
    ('salz', 'salt'),
    ('wasser', 'droplet'),
    ('eis', 'ice'),
    ('honig', 'honey_pot'),
    ('zucker', 'honey_pot'),
    ('schokolade', 'chocolate_bar'),
    ('kakao', 'chocolate_bar'),
    ('kaffee', 'hot_beverage'),
    ('wein', 'wine_glass'),
    ('öl', 'olive'),
    ('olive', 'olive'),
    ('zitrone', 'lemon'),
    ('zwiebel', 'onion'),
    ('knoblauch', 'garlic'),
    ('tomate', 'tomato'),
    ('kartoffel', 'potato'),
    ('karotte', 'carrot'),
    ('möhre', 'carrot'),
    ('gurke', 'cucumber'),
    ('erdbeere', 'strawberry'),
    ('apfel', 'red_apple'),
    ('banane', 'banana'),
    ('pilz', 'mushroom'),
    ('champignon', 'mushroom'),
    ('chili', 'hot_pepper'),
    ('paprika', 'bell_pepper'),
    ('brokkoli', 'broccoli'),
    ('spinat', 'leafy_green'),
    ('salat', 'leafy_green'),
    ('kräuter', 'herb'),
    ('petersilie', 'herb'),
    ('basilikum', 'herb'),
    ('avocado', 'avocado'),
    ('erdnuss', 'peanuts'),
    ('nuss', 'peanuts'),
    ('kokos', 'coconut'),
    ('traube', 'grapes'),
    ('kirsche', 'cherries'),
    ('pfirsich', 'peach'),
    ('ananas', 'pineapple'),
    ('heidelbeere', 'blueberries'),
    ('blaubeere', 'blueberries'),
    ('kiwi', 'kiwi_fruit'),
    ('speck', 'bacon'),
    ('hähnchen', 'poultry_leg'),
    ('huhn', 'poultry_leg'),
    ('fleisch', 'cut_of_meat'),
    ('hack', 'cut_of_meat'),
    ('fisch', 'fish'),
    ('lachs', 'fish'),
    ('garnele', 'shrimp'),
    ('reis', 'cooked_rice'),
    ('risotto', 'cooked_rice'),
    ('nudel', 'spaghetti'),
    ('spaghetti', 'spaghetti'),
    ('pasta', 'spaghetti'),
    ('suppe', 'pot_of_food'),
    ('eintopf', 'pot_of_food'),
  ];

  /// Allgemeine Bilder für Programme und leere Zustände.
  static const bowl = '$_dir/bowl_with_spoon_3d.png';
  static const pot = '$_dir/pot_of_food_3d.png';
  static const pan = '$_dir/shallow_pan_of_food_3d.png';
  static const rest = '$_dir/hourglass_not_done_3d.png';
  static const timer = '$_dir/timer_clock_3d.png';
  static const test = '$_dir/test_tube_3d.png';
  static const cooking = '$_dir/cooking_3d.png';

  /// Bild zu einem Namen (Zutat oder Programm), `null` wenn nichts passt.
  static String? forName(String name) {
    final n = name.toLowerCase();
    for (final (key, file) in _byKeyword) {
      if (_containsWord(n, key)) return '$_dir/${file}_3d.png';
    }
    return null;
  }

  /// Kurze Stichwörter wie „ei“ nur als eigenes Wort bzw. Wortanfang/-ende, damit
  /// „Weizenmehl“ nicht zu „Ei“ wird. Lange Stichwörter dürfen überall stehen.
  static bool _containsWord(String text, String key) {
    if (key.length > 3) return text.contains(key);
    return RegExp('(^|[^a-zäöüß])$key([^a-zäöüß]|\$)').hasMatch(text);
  }

  /// Lizenz von Fluent Emoji im Lizenz-Bildschirm der App anzeigen.
  static void registerLicense() {
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString(
        '$_dir/LICENSE-fluentui-emoji.txt',
      );
      yield LicenseEntryWithLineBreaks(['Fluent Emoji (Microsoft)'], text);
    });
  }
}

/// Illustration in fester Größe, ohne Rahmen. Fehlt das Bild, bleibt der Platz leer.
class Illustration extends StatelessWidget {
  const Illustration(this.asset, {super.key, this.size = 64});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    errorBuilder: (context, error, stack) =>
        SizedBox(width: size, height: size),
    semanticLabel: kDebugMode ? asset : null,
    excludeFromSemantics: !kDebugMode,
  );
}
