import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// Zutaten-Icons (assets/zutaten/, erzeugt von tool/zutaten_icons.py).
///
/// Nichts wird geraten: Ein Icon gibt es nur, wenn der ganze Name oder sein letztes Wort genau in
/// [_namen] steht. Zusätze wie „(M)“, „, weich“, „Type 550“ oder „zum Bestreichen“ fallen vorher
/// weg. Unbekannte Zutaten bekommen kein Icon – lieber keins als ein falsches.
abstract final class ZutatIcons {
  static const _dir = 'assets/zutaten';

  /// Name (klein, ohne Zusätze) → Icon-Datei. Ganze Namen gehen vor dem letzten Wort,
  /// deshalb steht z. B. „saure sahne“ hier, damit sie nicht zur Schlagsahne wird.
  static const _namen = <String, String>{
    // Mehl, Zucker, Backzutaten
    'mehl': 'mehl',
    'weizenmehl': 'mehl',
    'dinkelmehl': 'mehl',
    'roggenmehl': 'mehl',
    'vollkornmehl': 'mehl',
    'weizenvollkornmehl': 'mehl',
    'dinkelvollkornmehl': 'mehl',
    'pizzamehl': 'mehl',
    'zucker': 'zucker',
    'rohrzucker': 'zucker',
    'kristallzucker': 'zucker',
    'feinzucker': 'zucker',
    'backzucker': 'zucker',
    'puderzucker': 'puderzucker',
    'vanillezucker': 'vanillezucker', 'vanillinzucker': 'vanillezucker',
    'backpulver': 'backpulver',
    'sahnesteif': 'sahnesteif',
    'trockenhefe': 'trockenhefe',
    'hefe': 'hefe', 'frischhefe': 'hefe', 'würfelhefe': 'hefe',
    'speisestärke': 'speisestaerke',
    'stärke': 'speisestaerke',
    'maisstärke': 'speisestaerke',
    'kartoffelstärke': 'speisestaerke',
    'kakao': 'kakao', 'kakaopulver': 'kakao', 'backkakao': 'kakao',
    'schokolade': 'schokolade', 'zartbitterschokolade': 'schokolade',
    'vollmilchschokolade': 'schokolade', 'kuvertüre': 'schokolade',
    'zartbitterkuvertüre': 'schokolade',
    'honig': 'honig',
    'vanilleschote': 'vanille',
    'vanilleschoten': 'vanille',
    'vanille': 'vanille',
    'zimt': 'zimt', 'zimtstange': 'zimt', 'zimtstangen': 'zimt',
    // Milchprodukte und Ei
    'milch': 'milch', 'vollmilch': 'milch',
    'sahne': 'sahne', 'schlagsahne': 'sahne',
    'saure sahne': 'schmand', 'schmand': 'schmand', 'crème fraîche': 'schmand',
    'creme fraiche': 'schmand', 'sauerrahm': 'schmand',
    'joghurt': 'joghurt', 'naturjoghurt': 'joghurt',
    'quark': 'quark',
    'magerquark': 'quark',
    'speisequark': 'quark',
    'sahnequark': 'quark',
    'frischkäse': 'frischkaese',
    'mascarpone': 'frischkaese',
    'ricotta': 'frischkaese',
    'käse': 'kaese',
    'parmesan': 'kaese',
    'emmentaler': 'kaese',
    'gouda': 'kaese',
    'bergkäse': 'kaese',
    'butter': 'butter',
    'ei': 'ei', 'eier': 'ei',
    'eigelb': 'eigelb', 'eidotter': 'eigelb',
    'eiweiß': 'eiweiss', 'eiklar': 'eiweiss', 'eischnee': 'eiweiss',
    // Flüssiges und Würze
    'wasser': 'wasser',
    'öl': 'oel',
    'sonnenblumenöl': 'oel',
    'rapsöl': 'oel',
    'pflanzenöl': 'oel',
    'speiseöl': 'oel',
    'olivenöl': 'olivenoel',
    'weißwein': 'weisswein', 'weisswein': 'weisswein', 'rotwein': 'rotwein',
    'salz': 'salz', 'meersalz': 'salz', 'jodsalz': 'salz',
    'pfeffer': 'pfeffer',
    'muskat': 'muskat', 'muskatnuss': 'muskat',
    'zitrone': 'zitrone', 'zitronen': 'zitrone', 'zitronenschale': 'zitrone',
    'zitronensaft': 'zitronensaft',
    // Nüsse
    'mandeln': 'mandeln', 'mandel': 'mandeln', 'mandelblättchen': 'mandeln',
    'mandelstifte': 'mandeln',
    'haselnüsse': 'haselnuss',
    'haselnuss': 'haselnuss',
    'haselnusskerne': 'haselnuss',
    'walnüsse': 'walnuss', 'walnuss': 'walnuss', 'walnusskerne': 'walnuss',
    // Gemüse und Obst
    'zwiebel': 'zwiebel',
    'zwiebeln': 'zwiebel',
    'schalotte': 'zwiebel',
    'schalotten': 'zwiebel',
    'knoblauch': 'knoblauch',
    'knoblauchzehe': 'knoblauch',
    'knoblauchzehen': 'knoblauch',
    'tomate': 'tomate', 'tomaten': 'tomate', 'kirschtomaten': 'tomate',
    'kartoffel': 'kartoffel', 'kartoffeln': 'kartoffel',
    'karotte': 'karotte',
    'karotten': 'karotte',
    'möhre': 'karotte',
    'möhren': 'karotte',
    'apfel': 'apfel', 'äpfel': 'apfel',
    'banane': 'banane', 'bananen': 'banane',
    'erdbeere': 'erdbeere', 'erdbeeren': 'erdbeere',
    'heidelbeeren': 'beeren', 'heidelbeere': 'beeren', 'blaubeeren': 'beeren',
    'kräuter': 'kraeuter', 'petersilie': 'kraeuter', 'basilikum': 'kraeuter',
    'schnittlauch': 'kraeuter',
    'dill': 'kraeuter',
    'thymian': 'kraeuter',
    'rosmarin': 'kraeuter',
    // Herzhaft
    'reis': 'reis',
    'risottoreis': 'reis',
    'basmatireis': 'reis',
    'milchreis': 'reis',
    'nudeln': 'nudeln',
    'pasta': 'nudeln',
    'farfalle': 'nudeln',
    'penne': 'nudeln',
    'spaghetti': 'nudeln',
    'hackfleisch': 'fleisch', 'rinderhack': 'fleisch', 'rindfleisch': 'fleisch',
    'schweinefleisch': 'fleisch',
    'speck': 'speck', 'bacon': 'speck', 'speckwürfel': 'speck',
  };

  static final _mehrere = RegExp(r'(^|\s)(und|oder|mit)(\s|$)|[&/+]');
  static final _klammern = RegExp(r'\([^)]*\)');
  static final _type = RegExp(r'\b(type|typ|tipo)\s*\d+\b');
  static final _zahlen = RegExp(r'\b\d+([.,]\d+)?\b');
  static final _zweck = RegExp(r'\s(zum|zur|für|aus|nach|als)\s.*$');

  /// Asset-Pfad zum Namen oder `null`, wenn der Name nicht sicher bekannt ist.
  static String? forName(String name) {
    var n = name.toLowerCase().replaceAll(_klammern, ' ');
    n = n.split(',').first;
    // „Salz und Pfeffer“: zwei Zutaten, ein Icon wäre halb falsch.
    if (_mehrere.hasMatch(n)) return null;
    n = n.replaceAll(_type, ' ').replaceAll(_zahlen, ' ');
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
    n = n.replaceFirst(_zweck, '').trim();
    if (n.isEmpty) return null;
    final datei =
        _namen[n] ??
        _namen[n.split(' ').last] ??
        _namen[n.split(RegExp('[ -]')).last];
    return datei == null ? null : '$_dir/$datei.svg';
  }

  /// Alle Icon-Dateien (für Tests).
  static Iterable<String> get alleDateien =>
      _namen.values.toSet().map((d) => '$_dir/$d.svg');
}

/// Zutaten-Icon in fester Größe. Ohne bekanntes Icon bleibt der Platz leer, damit die Namen
/// untereinander bündig stehen.
class ZutatIcon extends StatelessWidget {
  const ZutatIcon(this.name, {super.key, this.size = 36});

  final String name;
  final double size;

  /// Lohnt sich eine Icon-Spalte? Nur wenn mindestens eine Zutat ein Icon hat.
  static bool irgendeins(Iterable<String> namen) =>
      namen.any((n) => ZutatIcons.forName(n) != null);

  @override
  Widget build(BuildContext context) {
    final pfad = ZutatIcons.forName(name);
    return SizedBox(
      width: size,
      height: size,
      child: pfad == null
          ? null
          : SvgPicture.asset(pfad, excludeFromSemantics: true),
    );
  }
}
