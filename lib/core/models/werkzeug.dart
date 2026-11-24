/// Rührelemente und Einsätze der KCL95 (Anleitung, Abschnitt Zubehör). Im Rezept pro Schritt
/// optional; der Kochmodus zeigt „… einsetzen“, wenn es sich gegenüber dem vorigen Schritt ändert.
///
/// Der JSON-Wert ist [name] – nicht umbenennen, er steht in gespeicherten Rezepten.
enum Werkzeug {
  kHaken,
  flexi,
  schneebesen,
  knethaken,
  kochRuehrelement,
  daempfeinsatz;

  static Werkzeug? fromJson(Object? v) {
    if (v is! String) return null;
    for (final w in values) {
      if (w.name == v) return w;
    }
    return null; // unbekannt (neuere App) → ignorieren
  }
}
