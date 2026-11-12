import '../models/models.dart';

/// Die Schnittstelle zur Freikoch Brücke nach `freikoch_esp/docs/api.md`.
///
/// Die Brücke ist die Quelle der Wahrheit; die App fragt ab, hört auf Ereignisse
/// und sendet Befehle. Neue Endpunkte kommen hier hinzu, sobald ein Feature sie
/// braucht (Rezepte, Programme, OTA …) – nicht vorher.
abstract class BridgeApi {
  /// `GET /api/v1/info`
  Future<BridgeInfo> info();

  /// `GET /api/v1/state`
  Future<ApplianceStatus> state();

  /// `POST /api/v1/machine/program` – Werte setzen. Gestartet wird am Gerät
  /// (sofern `caps.remoteStart` false). Die Bestätigung kommt als [AckEvent].
  Future<void> sendProgram(MachineSettings settings);

  /// `POST /api/v1/machine/stop`
  Future<void> stop();

  /// `POST /api/v1/machine/onboard` – Kopplung mit dem Gerät anstoßen.
  /// Fortschritt über [info] (`appliance.paired`/`connected`).
  Future<void> onboardMachine();

  /// `POST /api/v1/pair` – liefert den Token, sobald die Taste an der Brücke
  /// gedrückt wurde, sonst `null` (Brücke wartet, `202`).
  Future<String?> pair();

  /// Ereignisse vom WebSocket (`/api/v1/ws`). Broadcast-Stream; die Verbindung
  /// steht, solange jemand zuhört, und wird bei Abbruch neu aufgebaut.
  Stream<BridgeEvent> events();

  /// Verbindungen schließen, Timer beenden.
  void close();
}

/// Fehler beim Sprechen mit der Brücke.
class BridgeException implements Exception {
  const BridgeException(this.kind, [this.statusCode]);

  final BridgeErrorKind kind;
  final int? statusCode;

  @override
  String toString() => 'BridgeException($kind, $statusCode)';
}

enum BridgeErrorKind {
  /// Brücke nicht erreichbar (WLAN, IP falsch, ausgeschaltet).
  unreachable,

  /// Token fehlt oder ist ungültig → neu koppeln.
  unauthorized,

  /// Brücke hat den Befehl abgelehnt (z. B. Werte außerhalb der Grenzen).
  rejected,

  /// Unerwartete Antwort.
  protocol,
}
