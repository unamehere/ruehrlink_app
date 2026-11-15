import 'json.dart';

/// Live-Status des Geräts (`GET /api/v1/state` und WebSocket-Nachricht `status`).
/// Geräteneutrale Feldnamen; gerätespezifische Namen bleiben im Treiber der Brücke.
class ApplianceStatus {
  const ApplianceStatus({
    required this.connected,
    required this.running,
    required this.heating,
    required this.hot,
    required this.bowlFitted,
    required this.lidClosed,
    required this.bowlTemp,
    required this.tempSet,
    required this.speedSet,
    required this.remainingS,
    this.active = false,
    this.keepWarm = false,
  });

  /// Gerät ist nicht verbunden – nichts bekannt.
  static const disconnected = ApplianceStatus(
    connected: false,
    running: false,
    heating: false,
    hot: false,
    bowlFitted: false,
    lidClosed: false,
    bowlTemp: 0,
    tempSet: 0,
    speedSet: 0,
    remainingS: 0,
  );

  /// Gerät ist mit der Brücke verbunden.
  final bool connected;

  /// Motor dreht gerade (bei Rührintervallen im Wechsel an/aus).
  final bool running;

  /// Programm der Maschine läuft (auch Heizen ohne Motor, Intervallpausen). Ältere Brücken: immer false.
  final bool active;

  /// Warmhalten nach einem Heizprogramm (die Maschine startet es selbst, z. B. 30 min).
  final bool keepWarm;

  /// Heizung ist gerade aktiv.
  final bool heating;

  /// Schüssel ist heiß – Vorsicht beim Anfassen.
  final bool hot;
  final bool bowlFitted;

  /// Kopf/Deckel verriegelt.
  final bool lidClosed;

  /// Ist-Temperatur in der Schüssel, °C.
  final int bowlTemp;

  /// Eingestellte Temperatur, °C (0 = Heizung aus).
  final int tempSet;

  /// Eingestellte Stufe als Gerätewert – Anzeige über `ApplianceCaps.speedLabel`.
  final int speedSet;

  /// Restzeit in Sekunden. Zählt nur, solange der Motor läuft.
  final int remainingS;

  /// Schüssel eingesetzt und Kopf geschlossen – Voraussetzung zum Starten.
  bool get readyToStart => bowlFitted && lidClosed;

  factory ApplianceStatus.fromJson(Json json) => ApplianceStatus(
    connected: readBool(json['connected']),
    running: readBool(json['running']),
    heating: readBool(json['heating']),
    hot: readBool(json['hot']),
    bowlFitted: readBool(json['bowlFitted']),
    lidClosed: readBool(json['lidClosed']),
    bowlTemp: readInt(json['bowlTemp']),
    tempSet: readInt(json['tempSet']),
    speedSet: readInt(json['speedSet']),
    remainingS: readInt(json['remainingS']),
    active: readBool(json['active']),
    keepWarm: readBool(json['keepWarm']),
  );

  Json toJson() => {
    'connected': connected,
    'running': running,
    'heating': heating,
    'hot': hot,
    'bowlFitted': bowlFitted,
    'lidClosed': lidClosed,
    'bowlTemp': bowlTemp,
    'tempSet': tempSet,
    'speedSet': speedSet,
    'remainingS': remainingS,
    'active': active,
    'keepWarm': keepWarm,
  };

  ApplianceStatus copyWith({
    bool? connected,
    bool? running,
    bool? heating,
    bool? hot,
    bool? bowlFitted,
    bool? lidClosed,
    int? bowlTemp,
    int? tempSet,
    int? speedSet,
    int? remainingS,
    bool? active,
    bool? keepWarm,
  }) => ApplianceStatus(
    connected: connected ?? this.connected,
    running: running ?? this.running,
    heating: heating ?? this.heating,
    hot: hot ?? this.hot,
    bowlFitted: bowlFitted ?? this.bowlFitted,
    lidClosed: lidClosed ?? this.lidClosed,
    bowlTemp: bowlTemp ?? this.bowlTemp,
    tempSet: tempSet ?? this.tempSet,
    speedSet: speedSet ?? this.speedSet,
    remainingS: remainingS ?? this.remainingS,
    active: active ?? this.active,
    keepWarm: keepWarm ?? this.keepWarm,
  );
}
