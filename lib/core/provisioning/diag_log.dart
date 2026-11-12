import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Protokoll der Einrichtung (Bluetooth, Sitzung, Endpunkte) für die
/// ausklappbaren „Entwicklerdetails“ – damit sich Probleme aus einem
/// Bildschirmfoto erkennen lassen. Enthält nie Passwörter oder Token.
class DiagLog extends ChangeNotifier {
  static const _max = 80;
  final _lines = <String>[];

  List<String> get lines => List.unmodifiable(_lines);

  /// Letzte Zeile, z. B. für die Fehlerzeile.
  String? get last => _lines.isEmpty ? null : _lines.last;

  void add(String message) {
    final t = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    _lines.add('${two(t.hour)}:${two(t.minute)}:${two(t.second)} $message');
    if (_lines.length > _max) _lines.removeAt(0);
    if (kDebugMode) debugPrint('[Einrichtung] $message');
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}

final provisioningLogProvider = Provider<DiagLog>((ref) {
  final log = DiagLog();
  ref.onDispose(log.dispose);
  return log;
});
