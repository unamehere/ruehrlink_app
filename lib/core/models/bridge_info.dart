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
    required this.speeds,
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

  /// Alle wählbaren Stufen in Anzeige-Reihenfolge, gruppiert (aus, Intervall-Rühren,
  /// Dauerstufen). Die Werte sind gerätespezifisch und keine Zahlenskala.
  final List<SpeedOption> speeds;
  final int timeMaxS;
  final bool hasScale;

  /// Kann das Gerät aus der Ferne starten? Sonst: zum Starten den
  /// Knopf an der Maschine drücken.
  final bool remoteStart;

  /// Temperatur in den erlaubten Bereich bringen: unter [tempMin] → 0 (Heizung aus).
  int clampTemperature(int t) => t < tempMin ? 0 : (t > tempMax ? tempMax : t);

  /// Die Stufe zum Wert [v] oder `null`, wenn das Gerät sie nicht kennt.
  SpeedOption? speedOption(int v) {
    for (final o in speeds) {
      if (o.v == v) return o;
    }
    return null;
  }

  /// Anzeige für einen Stufenwert; unbekannte Werte als Zahl.
  String speedLabel(int v) => speedOption(v)?.label ?? '$v';

  /// Nur bekannte Stufen sind erlaubt, alles andere wird zu 0 (Motor aus).
  int clampSpeed(int s) => speedOption(s) != null ? s : 0;

  /// Stufen einer Gruppe, in der Reihenfolge der Brücke.
  List<SpeedOption> speedsIn(SpeedGroup group) => [
    for (final o in speeds)
      if (o.group == group) o,
  ];

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
    speeds: List.unmodifiable(readList(json['speeds'], SpeedOption.fromJson)),
    timeMaxS: readInt(json['timeMaxS']),
    hasScale: readBool(json['hasScale']),
    remoteStart: readBool(json['remoteStart']),
  );

  Json toJson() => {
    'model': model,
    'name': name,
    'tempMin': tempMin,
    'tempMax': tempMax,
    'speeds': [for (final o in speeds) o.toJson()],
    'timeMaxS': timeMaxS,
    'hasScale': hasScale,
    'remoteStart': remoteStart,
  };
}

/// Gruppe einer Stufe: aus, Intervall-Rühren (z. B. beim Kochen) oder Dauerstufe.
enum SpeedGroup {
  off,
  stir,
  continuous,

  /// Unbekannte Gruppe einer neueren Brücke – wird wie eine Dauerstufe gezeigt.
  other;

  static SpeedGroup parse(String s) => switch (s) {
    'off' => off,
    'stir' => stir,
    'continuous' => continuous,
    _ => other,
  };
}

/// Eine wählbare Stufe: [v] geht an die Maschine, [label] wird angezeigt.
class SpeedOption {
  const SpeedOption({
    required this.v,
    required this.label,
    required this.group,
    this.groupName,
  });

  final int v;
  final String label;
  final SpeedGroup group;

  /// Original-Gruppenname aus dem JSON (für unbekannte Gruppen).
  final String? groupName;

  factory SpeedOption.fromJson(Json json) {
    final g = readString(json['group']);
    return SpeedOption(
      v: readInt(json['v']),
      label: readString(json['label'], '${readInt(json['v'])}'),
      group: SpeedGroup.parse(g),
      groupName: g,
    );
  }

  Json toJson() => {'v': v, 'label': label, 'group': groupName ?? group.name};
}
