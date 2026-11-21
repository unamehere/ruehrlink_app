import 'json.dart';
import 'machine_settings.dart';

/// API-Hauptversionen, die diese App spricht (`api` in `GET /info`, siehe ruehrlink_esp/docs/api.md).
const appApis = {1};

/// Fähigkeiten einer Firmware 0.3.x – sie meldet `api: 1`, aber noch keine `features`.
const legacyFeatures = {
  'machine',
  'machine.onboard',
  'scale',
  'scale.tare',
  'sequence',
  'programs',
  'recipes',
  'media',
  'time',
  'pair',
  'reset',
  'ota',
};

/// Passen Rührlink und App zusammen?
enum BridgeCompat {
  ok,

  /// Der Rührlink spricht nur eine ältere API → Rührlink aktualisieren.
  bridgeTooOld,

  /// Der Rührlink spricht nur eine neuere API → App aktualisieren.
  appTooOld,
}

/// Antwort von `GET /api/v1/info`: die Brücke und das daran gekoppelte Gerät.
class BridgeInfo {
  const BridgeInfo({
    required this.id,
    required this.name,
    required this.fw,
    required this.api,
    this.apiSupported = const [1],
    this.features = legacyFeatures,
    this.storage,
    this.appliance,
  });

  final String id;
  final String name;

  /// Firmware-Version der Brücke, z. B. `0.1.0`.
  final String fw;

  /// Version der App-API (aktuell 1).
  final int api;

  /// Alle API-Hauptversionen, die der Rührlink gerade spricht (ältere Firmware: nur [api]).
  final List<int> apiSupported;

  /// Was die Firmware kann (`scale.tare`, `sequence` …). Ältere Firmware: [legacyFeatures].
  final Set<String> features;

  bool has(String feature) => features.contains(feature);

  BridgeCompat get compat {
    if (apiSupported.any(appApis.contains)) return BridgeCompat.ok;
    final newest = apiSupported.fold(api, (a, b) => a > b ? a : b);
    return newest < appApis.reduce((a, b) => a < b ? a : b)
        ? BridgeCompat.bridgeTooOld
        : BridgeCompat.appTooOld;
  }

  final StorageInfo? storage;
  final ApplianceInfo? appliance;

  /// Fähigkeiten des gekoppelten und verbundenen Geräts – sonst `null`.
  /// Spricht der Rührlink eine API, die diese App nicht kennt, ebenfalls `null`:
  /// dann zeigt die App nur den Status und steuert nichts.
  ApplianceCaps? get readyCaps =>
      compat == BridgeCompat.ok && appliance != null && appliance!.connected
      ? appliance!.caps
      : null;

  factory BridgeInfo.fromJson(Json json) {
    final api = readInt(json['api'], 1);
    final supported = json['apiSupported'] is List
        ? (json['apiSupported'] as List).whereType<num>().map((e) => e.toInt())
        : const <int>[];
    return BridgeInfo(
      id: readString(json['id']),
      name: readString(json['name']),
      fw: readString(json['fw']),
      api: api,
      apiSupported: List.unmodifiable(supported.isEmpty ? [api] : supported),
      features: json['features'] is List
          ? Set.unmodifiable((json['features'] as List).whereType<String>())
          : legacyFeatures,
      storage: json['storage'] is Map
          ? StorageInfo.fromJson(readMap(json['storage']))
          : null,
      appliance: json['appliance'] is Map
          ? ApplianceInfo.fromJson(readMap(json['appliance']))
          : null,
    );
  }

  Json toJson() => {
    'id': id,
    'name': name,
    'fw': fw,
    'api': api,
    'apiSupported': apiSupported,
    'features': features.toList(),
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
    this.hotTemp,
    this.hotSpeedMax,
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

  /// Ab dieser Temperatur (°C) gilt der Inhalt als heiß – dann sind nur Dauerstufen
  /// bis [hotSpeedMax] erlaubt. `null` bei älteren Brücken: keine Einschränkung bekannt.
  final int? hotTemp;
  final int? hotSpeedMax;

  /// Ist Stufe [v] bei heißem Inhalt zu schnell? (Rührintervalle sind immer erlaubt.)
  bool tooFastWhenHot(int v) {
    final limit = hotSpeedMax;
    final o = speedOption(v);
    if (limit == null || o == null || o.group != SpeedGroup.continuous) {
      return false;
    }
    return speeds.indexOf(o) > speeds.indexWhere((s) => s.v == limit);
  }

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
    hotTemp: json['hotTemp'] is num ? readInt(json['hotTemp']) : null,
    hotSpeedMax: json['hotSpeedMax'] is num
        ? readInt(json['hotSpeedMax'])
        : null,
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
    if (hotTemp != null) 'hotTemp': hotTemp,
    if (hotSpeedMax != null) 'hotSpeedMax': hotSpeedMax,
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
