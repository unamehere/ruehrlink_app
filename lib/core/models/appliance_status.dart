import 'json.dart';

/// Live-Status des Geräts (`GET /api/v1/state` und WebSocket-Nachricht `status`).
class ApplianceStatus {
  const ApplianceStatus({
    required this.bowlTemperature,
    required this.speedSetting,
    required this.remainingTime,
    required this.motorOn,
    required this.bowlFitted,
    required this.headLiftInterlockClosed,
    required this.connected,
  });

  /// Gerät ist nicht verbunden – nichts bekannt.
  static const disconnected = ApplianceStatus(
    bowlTemperature: 0,
    speedSetting: 0,
    remainingTime: 0,
    motorOn: false,
    bowlFitted: false,
    headLiftInterlockClosed: false,
    connected: false,
  );

  /// Ist-Temperatur in der Schüssel, °C.
  final int bowlTemperature;
  final int speedSetting;

  /// Restzeit in Sekunden. Zählt nur, solange der Motor läuft.
  final int remainingTime;
  final bool motorOn;
  final bool bowlFitted;
  final bool headLiftInterlockClosed;

  /// Gerät ist mit der Brücke verbunden.
  final bool connected;

  /// Schüssel eingesetzt und Kopf geschlossen – Voraussetzung zum Starten.
  bool get readyToStart => bowlFitted && headLiftInterlockClosed;

  factory ApplianceStatus.fromJson(Json json) => ApplianceStatus(
    bowlTemperature: readInt(json['bowlTemperature']),
    speedSetting: readInt(json['speedSetting']),
    remainingTime: readInt(json['remainingTime']),
    motorOn: readBool(json['motorOn']),
    bowlFitted: readBool(json['bowlFitted']),
    // Schreibweise mit großem H so in der API festgelegt.
    headLiftInterlockClosed: readBool(json['HeadLiftInterlockClosed']),
    connected: readBool(json['connected']),
  );

  Json toJson() => {
    'bowlTemperature': bowlTemperature,
    'speedSetting': speedSetting,
    'remainingTime': remainingTime,
    'motorOn': motorOn,
    'bowlFitted': bowlFitted,
    'HeadLiftInterlockClosed': headLiftInterlockClosed,
    'connected': connected,
  };

  ApplianceStatus copyWith({
    int? bowlTemperature,
    int? speedSetting,
    int? remainingTime,
    bool? motorOn,
    bool? bowlFitted,
    bool? headLiftInterlockClosed,
    bool? connected,
  }) => ApplianceStatus(
    bowlTemperature: bowlTemperature ?? this.bowlTemperature,
    speedSetting: speedSetting ?? this.speedSetting,
    remainingTime: remainingTime ?? this.remainingTime,
    motorOn: motorOn ?? this.motorOn,
    bowlFitted: bowlFitted ?? this.bowlFitted,
    headLiftInterlockClosed:
        headLiftInterlockClosed ?? this.headLiftInterlockClosed,
    connected: connected ?? this.connected,
  );
}
