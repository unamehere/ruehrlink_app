// Zutaten-Icons: nur sichere Treffer, unbekannte Zutaten bekommen keins.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/ui/zutat_icons.dart';

String? _icon(String name) {
  final p = ZutatIcons.forName(name);
  return p?.split('/').last.replaceAll('.svg', '');
}

void main() {
  test('Namen aus den Grundrezepten treffen das richtige Icon', () {
    const erwartet = {
      'Weizenmehl 405': 'mehl',
      'Mehl (Weizen 405)': 'mehl',
      'Mehl (Weizen-Vollkorn)': 'mehl',
      'Feiner Zucker': 'zucker',
      'Vanillezucker': 'vanillezucker',
      'Wasser, lauwarm': 'wasser',
      'Milch, kalt': 'milch',
      'Butter, weich': 'butter',
      'Sahne (mind. 30 % Fett), kalt': 'sahne',
      'Schlagsahne': 'sahne',
      'Frische Hefe': 'hefe',
      'Trockenhefe': 'trockenhefe',
      'Eier': 'ei',
      '1 Ei (M)': 'ei',
      'Eigelb zum Bestreichen': 'eigelb',
      'Eiweiß': 'eiweiss',
      'Muskatnuss, gerieben': 'muskat',
      'Pfeffer aus der Mühle': 'pfeffer',
      'Zartbitter-Schokolade': 'schokolade',
      'Olivenöl': 'olivenoel',
      'Sonnenblumenöl': 'oel',
      'gehackte Mandeln': 'mandeln',
      'Saure Sahne': 'schmand',
      'Mehl Type 550': 'mehl',
    };
    erwartet.forEach((name, icon) => expect(_icon(name), icon, reason: name));
  });

  test('Unbekanntes oder Zusammengesetztes bekommt kein Icon', () {
    for (final name in [
      'Erdnussbutter',
      'Kokosmilch',
      'Buttermilch',
      'Reismehl', // kein eigener Eintrag – lieber keins als Weizenmehl raten
      'Brei',
      'Preiselbeeren',
      'Salz und Pfeffer',
      'Mehl oder Grieß',
      'Tomatenmark',
      'Eisbein',
      '',
      '200 g',
    ]) {
      expect(ZutatIcons.forName(name), isNull, reason: name);
    }
  });

  test('Alle Icon-Dateien liegen klein im Projekt', () {
    for (final pfad in ZutatIcons.alleDateien) {
      final f = File(pfad);
      expect(f.existsSync(), isTrue, reason: pfad);
      expect(f.lengthSync(), lessThan(4 * 1024), reason: pfad);
    }
  });
}
