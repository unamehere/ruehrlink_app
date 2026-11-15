// Pfade aus dem Piktogramm-Entwurf (bilder/werkzeuge.pdf, Artifact „Rühri Werkzeug-Piktogramme“, 15.11.2026)
// übernommen. Änderungen am Aussehen bitte zuerst im Entwurf, dann hier.
//
// Eigene, vereinfachte Strich-Piktogramme (64er-Raster) nach Ansicht und Proportion der Teile –
// keine Herstellergrafiken.

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';

/// Zubehörteile der KCL95, für die es ein Piktogramm gibt.
enum Teil {
  kHaken,
  flexi,
  schneebesen,
  knethaken,
  kochRuehrelement,
  ruehrhilfeclip,
  spatel,
  teigschaber,
  daempfeinsatz,
  spritzschutz,
  hitzeschild,
}

/// SVG-Inhalt (ohne `<svg>`-Hülle) je Teil. Klassen: `f` = mit Hintergrund gefüllt, `bar`/`tube` = dicker,
/// `dots` = gefüllte Punkte.
const _svg = <Teil, String>{
  Teil.kHaken: '<path d="M32 3v7"/><path class="f" d="M29.5 10h5v3h-5z"/><path class="f" fill-rule="evenodd" d="M13 20Q12 16.5 16 16.5H48Q52 16.5 51 20C49.5 35 45 51 36.5 56.5Q32 59 27.5 56.5C19 51 14.5 35 13 20Z M18.5 21.5H45.5C44 33 41 46 34.5 51.5Q32 53 29.5 51.5C23 46 20 33 18.5 21.5Z"/><ellipse class="f" cx="32" cy="14.5" rx="10" ry="2.6"/><path class="bar" d="M26 22.5v27M26.5 37L44.5 22.5M26.5 37L36.5 49.5"/>',
  Teil.flexi: '<path d="M32 3v4"/><path d="M29.5 7.5l5 1.5-5 1.5 5 1.5-5 1.5 5 1.5"/><path class="f" d="M8 19Q10 42 25 59.5l3-2.5Q16 41 13.5 19Z"/><path class="f" fill-rule="evenodd" d="M13 20Q12 16.5 16 16.5H48Q52 16.5 51 20C49.5 35 45 51 36.5 56.5Q32 59 27.5 56.5C19 51 14.5 35 13 20Z M18.5 21.5H45.5C44 33 41 46 34.5 51.5Q32 53 29.5 51.5C23 46 20 33 18.5 21.5Z"/><path d="M51 18l7-3.5"/>',
  Teil.schneebesen: '<path d="M32 3v7"/><path class="f" d="M29.5 10h5v3h-5z"/><path d="M26 18.5C9 24 13 50 32 58C51 50 55 24 38 18.5"/><path d="M28 18.5C17 26 21 50 32 58C43 50 47 26 36 18.5"/><path d="M30 18.5C25 30 27 50 32 58C37 50 39 30 34 18.5"/><path d="M32 18v43"/><path class="f" d="M26 15v3a6 2 0 0 0 12 0v-3"/><ellipse class="f" cx="32" cy="15" rx="6" ry="2"/>',
  Teil.knethaken: '<path d="M32 3v10"/><path class="tube" d="M43 18C51 24 47 34 37 41C27 49 25 57 33 58.5C36 59 37.5 56 35 54.5"/><path class="f" d="M19 15c0 2.8 5 5 13 5s13-2.2 13-5"/><ellipse class="f" cx="32" cy="15" rx="13" ry="3.4"/><ellipse cx="32" cy="15" rx="8" ry="1.8"/>',
  Teil.kochRuehrelement: '<path d="M18 3v10"/><path class="tube" d="M22 16.5H40Q47 16.5 46.5 24C45.5 36 35 42 31 51"/><rect class="f" x="13.5" y="13" width="9" height="7" rx="1.2"/><path class="f" d="M16 58Q12.5 58 14.5 55L18.5 51Q20.5 49.5 23.5 49.5H37.5Q41.5 49.5 39.5 52.5L36.5 56.5Q35.5 58 33 58Z"/>',
  Teil.ruehrhilfeclip: '<path class="f" d="M27 25Q25 44 28 57Q31 61 33.5 56Q36.5 42 38 25Z"/><path d="M31.5 30Q30.5 44 31.5 54"/><path class="f" d="M9 19Q9 14 14 14.5L48 13Q54 13 54 18Q54 22 49 22L15 23.5Q9 24 9 19Z"/><path d="M24 23v3.5h15V22"/>',
  Teil.spatel: '<path class="f" d="M29 4h6v34l4 4v17l-2 2h-10l-2-2V42l4-4z"/><circle cx="32" cy="8.5" r="1.6"/><path d="M30.5 13v22"/>',
  Teil.teigschaber: '<path class="f" d="M21 22Q33 16 45 18Q47 18 47 21V50Q33 58 21 53Q17 52 17 48V27Q17 24 21 22Z"/><circle cx="32" cy="36" r="2.5"/>',
  Teil.daempfeinsatz: '<path class="f" d="M5 36v7a27 13 0 0 0 54 0v-7"/><ellipse class="f" cx="32" cy="36" rx="27" ry="13"/><ellipse cx="32" cy="36" rx="23" ry="10.5"/><path d="M16 33l6-4h20l6 4M16 39l6 4h20l6-4"/><g class="dots"><circle cx="27" cy="31" r="1.4"/><circle cx="37" cy="31" r="1.4"/><circle cx="32" cy="33" r="1.4"/><circle cx="22" cy="36" r="1.4"/><circle cx="42" cy="36" r="1.4"/><circle cx="27" cy="36" r="1.4"/><circle cx="37" cy="36" r="1.4"/><circle cx="32" cy="39" r="1.4"/><circle cx="27" cy="41" r="1.4"/><circle cx="37" cy="41" r="1.4"/><circle cx="12" cy="36" r="1.4"/><circle cx="52" cy="36" r="1.4"/></g><path d="M30 23.3v2.4M34 23.3v2.4M30 46.3v2.4M34 46.3v2.4"/>',
  Teil.spritzschutz: '<path class="f" d="M3 38v3a29 13 0 0 0 58 0v-3"/><ellipse class="f" cx="32" cy="38" rx="29" ry="13"/><path style="stroke:none" class="f" d="M19.6 24H42.4V27Q42.4 35.4 31 35.4Q19.6 35.4 19.6 27Z"/><path class="f" d="M19 18V26.4Q19 42 31 42Q43 42 43 26.4V18Q43 35 31 35Q19 35 19 18Z"/><path class="f" d="M37 45.5Q47 41.5 56 41.5Q59.5 42 58 45Q55 49.5 46 51Q40 52 37.5 49.5Z"/><ellipse class="f" cx="39" cy="48" rx="2.6" ry="1.7"/>',
  Teil.hitzeschild: '<path class="f" d="M18 51v3a14 4 0 0 0 28 0v-3"/><ellipse class="f" cx="32" cy="51" rx="14" ry="4"/><path class="f" d="M52 13l6-3v28l-6 3z"/><path class="f" d="M12 20V33Q12 48 32 48Q52 48 52 33V20Q52 35 32 35Q12 35 12 20Z"/><path class="f" d="M12 20l7-6v8"/><path d="M41 39.5l2.5-4 2.5 4z"/>',
};

/// Piktogramm zu einem Rezept-Werkzeug.
Teil werkzeugTeil(Werkzeug w) => switch (w) {
  Werkzeug.kHaken => Teil.kHaken,
  Werkzeug.flexi => Teil.flexi,
  Werkzeug.schneebesen => Teil.schneebesen,
  Werkzeug.knethaken => Teil.knethaken,
  Werkzeug.kochRuehrelement => Teil.kochRuehrelement,
  Werkzeug.daempfeinsatz => Teil.daempfeinsatz,
};

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Vollständiges SVG mit festen Farben (flutter_svg kennt keine CSS-Klassen).
String teilSvg(
  Teil t, {
  required Color fg,
  required Color bg,
  double stroke = 2.3,
}) {
  final f = _hex(fg), b = _hex(bg);
  final body = _svg[t]!
      .replaceAll('style="stroke:none" class="f"', 'stroke="none" fill="$b"')
      .replaceAll('class="f"', 'fill="$b"')
      .replaceAll('class="bar"', 'stroke-width="3.6"')
      .replaceAll('class="tube"', 'stroke-width="4.6"')
      .replaceAll('class="dots"', 'fill="$f" stroke="none"');
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" '
      'stroke="$f" stroke-width="$stroke" stroke-linecap="round" '
      'stroke-linejoin="round">$body</svg>';
}

/// Piktogramm eines Teils. [background] füllt die Flächen, die Linien dahinter verdecken – muss zur
/// Fläche passen, auf der es steht (Standard: Kartenfarbe).
class TeilBild extends StatelessWidget {
  const TeilBild(
    this.teil, {
    super.key,
    this.size = 40,
    this.color,
    this.background,
    this.semanticLabel,
  });

  final Teil teil;
  final double size;
  final Color? color;
  final Color? background;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg =
        color ?? IconTheme.of(context).color ?? theme.colorScheme.onSurface;
    final bg =
        background ??
        theme.cardTheme.color ??
        theme.colorScheme.surfaceContainerLow;
    return SvgPicture.string(
      teilSvg(teil, fg: fg, bg: bg, stroke: size < 32 ? 3 : 2.3),
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
