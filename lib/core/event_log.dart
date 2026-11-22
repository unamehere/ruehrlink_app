import 'package:flutter/foundation.dart';

/// Kleines Ereignisprotokoll der App für „Problem melden“: die letzten [capacity] Ereignisse
/// (Verbindung, Fehler der Bridge-API, Kochmodus-Schritte, Updates …) im RAM, nichts auf der Platte.
///
/// Bleibt bewusst ohne Riverpod, damit auch Code ohne `ref` (z. B. [HttpBridgeApi], Fehler-Handler in
/// `main.dart`) hineinschreiben kann – global über [appEvents].
///
/// Nie Token, Passwörter oder WLAN-Schlüssel hineinschreiben. Als zweite Sicherung maskiert [add]
/// trotzdem alles, was danach aussieht ([maskSecrets]).
class EventLog {
  EventLog({this.capacity = 200, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final int capacity;
  final DateTime Function() _clock;
  final _entries = <AppEvent>[];
  int _dropped = 0;

  /// Älteste zuerst.
  List<AppEvent> get entries => List.unmodifiable(_entries);

  /// So viele ältere Ereignisse sind schon herausgefallen.
  int get dropped => _dropped;

  /// [category] kurz und fest (`verbindung`, `api`, `kochmodus`, `update`, `fehler` …).
  void add(String category, String message) {
    var text = maskSecrets(message.trim());
    if (text.length > 300) text = '${text.substring(0, 300)} …';
    // Gleiche Meldung direkt hintereinander (z. B. Warten auf den Neustart) nur zählen.
    final last = _entries.isEmpty ? null : _entries.last;
    if (last != null && last.category == category && last.message == text) {
      _entries[_entries.length - 1] = AppEvent(
        last.time,
        category,
        text,
        count: last.count + 1,
        lastTime: _clock(),
      );
      return;
    }
    _entries.add(AppEvent(_clock(), category, text));
    if (_entries.length > capacity) {
      _entries.removeAt(0);
      _dropped++;
    }
    if (kDebugMode) debugPrint('[$category] $text');
  }

  void clear() {
    _entries.clear();
    _dropped = 0;
  }

  /// Eine Zeile pro Ereignis, z. B. `2026-11-23 18:04:12.345 [api] GET info → 401`.
  List<String> lines() => [for (final e in _entries) e.toString()];
}

class AppEvent {
  const AppEvent(
    this.time,
    this.category,
    this.message, {
    this.count = 1,
    this.lastTime,
  });

  final DateTime time;
  final String category;
  final String message;

  /// So oft kam die Meldung direkt hintereinander, zuletzt um [lastTime].
  final int count;
  final DateTime? lastTime;

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _clock(DateTime t) =>
      '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

  @override
  String toString() {
    final t = time;
    final ms = t.millisecond.toString().padLeft(3, '0');
    final repeat = count > 1 ? ' (×$count bis ${_clock(lastTime ?? t)})' : '';
    return '${t.year}-${_two(t.month)}-${_two(t.day)} ${_clock(t)}.$ms '
        '[$category] $message$repeat';
  }
}

/// Das Protokoll der laufenden App.
final appEvents = EventLog();

final _keyValue = RegExp(
  r'''(?<![A-Za-z])((?:password|passwort|passwd|pass|pwd|psk|pop|token|secret|key|authorization)["']?\s*[:=]\s*["']?)(?:bearer\s+)?[^\s"',;&}]+''',
  caseSensitive: false,
);
final _bearer = RegExp(r'(bearer\s+)[A-Za-z0-9._~+/=-]+', caseSensitive: false);

/// App-Tokens sind 32 Hex-Zeichen; SHA-256-Namen (64) bleiben lesbar.
final _hex32 = RegExp(r'(?<![0-9A-Za-z])[0-9a-fA-F]{32}(?![0-9A-Za-z])');

/// Zugangsdaten unkenntlich machen: Werte nach `password|pass|pop|token|key …` mit `:`/`=`,
/// `Bearer …`, 32-stellige Hex-Folgen und alle ausdrücklich genannten [secrets].
String maskSecrets(String text, {Iterable<String?> secrets = const []}) {
  var out = text;
  for (final s in secrets) {
    if (s != null && s.length >= 4) out = out.replaceAll(s, '***');
  }
  out = out.replaceAllMapped(_bearer, (m) => '${m[1]}***');
  out = out.replaceAllMapped(_keyValue, (m) => '${m[1]}***');
  return out.replaceAll(_hex32, '***');
}
