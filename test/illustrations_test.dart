import 'package:flutter_test/flutter_test.dart';
import 'package:freikoch/ui/illustrations.dart';

void main() {
  test('Zutaten finden ihr Bild, kurze Stichwörter nur als ganzes Wort', () {
    expect(
      Illustrations.forName('500 g Weizenmehl 550'),
      contains('sheaf_of_rice'),
    );
    expect(Illustrations.forName('2 Eier'), contains('egg'));
    expect(Illustrations.forName('1 Ei (M)'), contains('egg'));
    expect(Illustrations.forName('Olivenöl'), contains('olive'));
    expect(Illustrations.forName('Weizen'), isNull);
    expect(Illustrations.forName('Eischnee'), contains('egg'));
    expect(Illustrations.forName('Eisbein'), isNull);
  });
}
