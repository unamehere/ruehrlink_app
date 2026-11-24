import 'dart:typed_data';

import '../models/models.dart';

/// Die Schnittstelle zum Rührlink nach `ruehrlink_esp/docs/api.md`.
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

  /// `POST /api/v1/sequence/start` mit dem ganzen Programm (Schritte inline).
  /// Die Brücke prüft es und sendet Schritt 1; gestartet wird am Gerät.
  /// Abgelehnt → [BridgeException] mit [BridgeException.code] (`hot_speed`, `not_ready` …).
  Future<SequenceState> startSequence(Program program);

  /// `POST /api/v1/sequence/abort` – Programm abbrechen, stoppt auch die Maschine.
  Future<void> abortSequence();

  /// `GET /api/v1/sequence` – aktueller Stand, z. B. nach dem Wiederverbinden.
  Future<SequenceState> sequence();

  /// `GET /api/v1/programs` – auf der Brücke gespeicherte Programme.
  Future<List<Program>> programs();

  /// `GET /api/v1/recipes?since=<rev>` – Änderungen der Rezeptbibliothek seit [since]
  /// (0 = alles). Ist `rev` der Antwort kleiner als [since], muss die App alles neu holen.
  Future<RecipeChanges> recipeChanges(int since);

  /// `PUT /api/v1/recipes/{id}` mit `If-Match: <recipe.rev>` (0 = neues Rezept).
  /// Hat jemand anderes inzwischen geändert oder gelöscht → [RecipeConflict] statt Überschreiben.
  Future<RecipeWriteResult> putRecipe(Recipe recipe);

  /// `DELETE /api/v1/recipes/{id}` mit `If-Match: <rev>`.
  Future<RecipeWriteResult> deleteRecipe(String id, {required int rev});

  /// `GET /api/v1/media/{sha256}` – Foto (WebP). Unveränderlich, darf dauerhaft zwischengespeichert werden.
  Future<Uint8List> media(String sha256);

  /// `PUT /api/v1/media/{sha256}` – Foto hochladen (WebP, max. 1 MB). Vor dem Rezept, das darauf verweist.
  Future<void> putMedia(String sha256, Uint8List webp);

  /// `POST /api/v1/machine/onboard` – Kopplung mit dem Gerät anstoßen.
  /// Fortschritt per [OnboardEvent]; währenddessen ist die Brücke im Heim-WLAN
  /// nicht erreichbar, das Ergebnis steht danach in [info] (`appliance.connected`).
  Future<void> onboardMachine();

  /// `POST /api/v1/scale/watch` – Waage für [seconds] Sekunden liefern lassen. Solange die App
  /// die Waage zeigt, alle ~10 s erneuern; danach schaltet die Brücke sie ab (spart RAM).
  /// Werte kommen als [WeightEvent]. Ohne Waage → [BridgeException] `no_scale` (501),
  /// Maschine nicht verbunden → `not_connected` (409).
  Future<void> watchScale({int seconds = 30});

  /// `POST /api/v1/scale/tare` – aktuelles Gewicht als Null setzen; liefert die Tara in Gramm.
  /// Noch kein Messwert → [BridgeException] `no_weight` (409).
  Future<double> tareScale();

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

  /// `POST /api/v1/ota` – Firmware-Image hochladen (Prüfsumme und Signatur aus dem Manifest).
  /// [onProgress] bekommt 0…1. Danach startet die Brücke neu; ob die neue Firmware läuft,
  /// zeigt `fw` in [info]. Abgelehnt → [BridgeException] mit `busy`, `signature`, `sha256` …
  Future<void> uploadFirmware(
    Uint8List image, {
    required String sha256,
    required String signature,
    void Function(double progress)? onProgress,
  });

  /// Ereignisse vom WebSocket (`/api/v1/ws`). Broadcast-Stream; die Verbindung
  /// steht, solange jemand zuhört, und wird bei Abbruch neu aufgebaut.
  Stream<BridgeEvent> events();

  /// Live-Verbindung sofort neu aufbauen, z. B. wenn die App nach dem Entsperren wieder in den
  /// Vordergrund kommt (eine schlafende Verbindung merkt man sonst erst nach Sekunden, F5).
  void reconnect();

  /// Verbindungen schließen, Timer beenden.
  void close();
}

/// Fehler beim Sprechen mit der Brücke.
class BridgeException implements Exception {
  const BridgeException(this.kind, [this.statusCode, this.code]);

  final BridgeErrorKind kind;
  final int? statusCode;

  /// Fehlercode aus der Antwort (`{"error":"…"}`), z. B. `busy` oder `hot_speed`.
  final String? code;

  @override
  String toString() => 'BridgeException($kind, $statusCode, $code)';
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
