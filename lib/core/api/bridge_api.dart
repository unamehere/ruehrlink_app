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
  /// Fortschritt per [OnboardEvent]; währenddessen ist die Brücke im Heim-WLAN
  /// nicht erreichbar, das Ergebnis steht danach in [info] (`appliance.connected`).
  Future<void> onboardMachine();

  /// `POST /api/v1/pair` mit `{"name"}` – Kopplung anfragen, liefert die Anfrage-ID.
  /// Ein schon gekoppeltes Handy muss die Anfrage bestätigen.
  Future<String> requestPairing(String deviceName);

  /// `POST /api/v1/pair` mit `{"id"}` – Token, sobald bestätigt, sonst `null`
  /// (wartet noch). Abgelaufene Anfrage → [BridgeException] `rejected`.
  Future<String?> pollPairing(String requestId);

  /// `POST /api/v1/pair/approve` – Anfrage eines neuen Geräts erlauben.
  /// Abgelaufen → [BridgeException] `rejected` mit Status 404.
  Future<void> approvePairing(String requestId);

  /// `POST /api/v1/time` – Uhrzeit setzen (die Brücke hat kein NTP).
  /// Zeitzone wird weggelassen (ohne Zusatzpaket nicht als IANA-Name verfügbar).
  Future<void> setTime(DateTime now);

  /// `POST /api/v1/reset` – Werksreset: Heim-WLAN, App-Kopplungen und
  /// Maschinen-Kopplung werden gelöscht, die Brücke startet neu.
  Future<void> reset();

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
