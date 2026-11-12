import 'json.dart';
import 'machine_settings.dart';

/// Antwort von `GET /api/v1/info`: die Brücke und das daran gekoppelte Gerät.
class BridgeInfo {
  const BridgeInfo({
    required this.id,
    required this.name,
    required this.fw,
    required this.api,
    this.storage,
    this.appliance,
  });

  final String id;
  final String name;

  /// Firmware-Version der Brücke, z. B. `0.1.0`.
  final String fw;

  /// Version der App-API (aktuell 1).
  final int api;
  final StorageInfo? storage;
  final ApplianceInfo? appliance;

  /// Fähigkeiten des gekoppelten und verbundenen Geräts – sonst `null`.
  ApplianceCaps? get readyCaps =>
      appliance != null && appliance!.connected ? appliance!.caps : null;

  factory BridgeInfo.fromJson(Json json) => BridgeInfo(
    id: readString(json['id']),
    name: readString(json['name']),
    fw: readString(json['fw']),
    api: readInt(json['api'], 1),
    storage: json['storage'] is Map
        ? StorageInfo.fromJson(readMap(json['storage']))
        : null,
    appliance: json['appliance'] is Map
        ? ApplianceInfo.fromJson(readMap(json['appliance']))
        : null,
  );

  Json toJson() => {
    'id': id,
    'name': name,
    'fw': fw,
    'api': api,
    if (storage != null) 'storage': storage!.toJson(),
    if (appliance != null) 'appliance': appliance!.toJson(),
  };
}

class StorageInfo {
  const StorageInfo({
    required this.backend,
    required this.totalKB,
    required this.freeKB,
  });

  /// `sd` oder `flash`.
  final String backend;
  final int totalKB;
  final int freeKB;

  factory StorageInfo.fromJson(Json json) => StorageInfo(
    backend: readString(json['backend']),
    totalKB: readInt(json['totalKB']),
    freeKB: readInt(json['freeKB']),
  );

  Json toJson() => {'backend': backend, 'totalKB': totalKB, 'freeKB': freeKB};
}

class ApplianceInfo {
  const ApplianceInfo({
    required this.paired,
    required this.connected,
    this.caps,
  });

  /// Gerät wurde einmal mit der Brücke gekoppelt.
  final bool paired;

  /// Gerät ist gerade mit der Brücke verbunden.
  final bool connected;
  final ApplianceCaps? caps;

  factory ApplianceInfo.fromJson(Json json) => ApplianceInfo(
    paired: readBool(json['paired']),
    connected: readBool(json['connected']),
    caps: json['caps'] is Map
        ? ApplianceCaps.fromJson(readMap(json['caps']))
        : null,
  );

  Json toJson() => {
    'paired': paired,
    'connected': connected,
    if (caps != null) 'caps': caps!.toJson(),
  };
}

/// Fähigkeiten eines Geräts. **Alle Regler und Grenzen der App kommen von hier**
/// – nie fest im Code. So läuft ein weiteres Gerät ohne App-Update.
class ApplianceCaps {
  const ApplianceCaps({
    required this.model,
    required this.name,
    required this.tempMin,
    required this.tempMax,
    required this.speedMax,
    required this.timeMaxS,
    required this.hasScale,
    required this.remoteStart,
  });

  /// Technische Modellkennung, nur zur Anzeige/Diagnose.
  final String model;

  /// Anzeigename des Geräts.
  final String name;

  /// Kleinste einstellbare Heiztemperatur in °C. Darunter heißt es „aus“ (0).
  final int tempMin;
  final int tempMax;

  /// Höchste Stufe; 0 = Motor aus.
  final int speedMax;
  final int timeMaxS;
  final bool hasScale;

  /// Kann das Gerät aus der Ferne starten? Sonst: Start am Knopf der Maschine.
  final bool remoteStart;

  /// Temperatur in den erlaubten Bereich bringen: unter [tempMin] → 0 (Heizung aus).
  int clampTemperature(int t) => t < tempMin ? 0 : (t > tempMax ? tempMax : t);

  int clampSpeed(int s) => s.clamp(0, speedMax);

  int clampTime(int seconds) => seconds.clamp(0, timeMaxS);

  /// Alle drei Werte auf einmal begrenzen.
  MachineSettings clamp(MachineSettings s) => MachineSettings(
    temperature: clampTemperature(s.temperature),
    time: clampTime(s.time),
    speed: clampSpeed(s.speed),
  );

  factory ApplianceCaps.fromJson(Json json) => ApplianceCaps(
    model: readString(json['model']),
    name: readString(json['name']),
    tempMin: readInt(json['tempMin']),
    tempMax: readInt(json['tempMax']),
    speedMax: readInt(json['speedMax']),
    timeMaxS: readInt(json['timeMaxS']),
    hasScale: readBool(json['hasScale']),
    remoteStart: readBool(json['remoteStart']),
  );

  Json toJson() => {
    'model': model,
    'name': name,
    'tempMin': tempMin,
    'tempMax': tempMax,
    'speedMax': speedMax,
    'timeMaxS': timeMaxS,
    'hasScale': hasScale,
    'remoteStart': remoteStart,
  };
}
