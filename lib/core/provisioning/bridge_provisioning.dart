import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../discovery/bridge_discovery.dart';
import '../models/json.dart';
import '../models/models.dart';
import 'ble_bridge_provisioning.dart';
import 'diag_log.dart';

/// Einrichtung einer Brücke per Bluetooth (ESP-IDF protocomm, Security 2).
/// Ablauf siehe `ruehrlink_esp/docs/architektur.md`, „Einrichtung per Bluetooth“:
///
/// 1. [scan] findet Brücken im Einrichtungsmodus (`Ruehrlink-XXXX`).
/// 2. [connect] öffnet mit dem Code vom QR-Etikett eine verschlüsselte Sitzung.
/// 3. [info] (`rl-info`): Ist das Heim-WLAN schon verbunden, entfällt 4.
/// 4. [scanWifi] (`rl-scan`) und [joinWifi] (`rl-wifi`, dann `rl-info` abfragen).
/// 5. [finish] holt den Token (`rl-token`) und liefert das Ziel im WLAN.
abstract class BridgeProvisioning {
  Stream<List<ProvisionableBridge>> scan();

  Future<void> connect(ProvisionableBridge bridge, {required SetupCode code});

  Future<BridgeSetupInfo> info();

  Future<List<WifiNetwork>> scanWifi();

  /// Wirft [ProvisioningException] mit `wrongPassword`, `wifiNotFound` oder
  /// `wifiFailed`, wenn die Brücke sich nicht verbinden kann.
  Future<void> joinWifi(String ssid, String password);

  /// Token holen, Brücke im WLAN auffinden, Bluetooth trennen.
  Future<BridgeTarget> finish();

  /// Sitzung beenden (auch bei Abbruch).
  Future<void> disconnect();
}

/// Inhalt des QR-Codes auf dem Etikett – oder nur der abgetippte Code.
class SetupCode {
  const SetupCode({required this.pop, this.name, this.username = 'ruehrlink'});

  /// Einrichtungs-Code (Proof of Possession).
  final String pop;

  /// Bluetooth-Name, z. B. `Ruehrlink-98C0` (nur aus dem QR-Code bekannt).
  final String? name;
  final String username;

  /// QR-JSON (`{"ver":"v1","name":…,"pop":…}`) oder abgetippter Code.
  /// `null`, wenn nichts Brauchbares darin steht.
  static SetupCode? parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('{')) {
      try {
        final j = readMap(jsonDecode(text));
        final pop = readString(j['pop']);
        if (pop.isEmpty) return null;
        final name = readString(j['name']);
        return SetupCode(
          pop: pop,
          name: name.isEmpty ? null : name,
          username: readString(j['username'], 'ruehrlink'),
        );
      } on FormatException {
        return null;
      }
    }
    // Abgetippt: Leerzeichen/Bindestriche ignorieren, Groß-/Kleinschreibung egal.
    final pop = text.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
    return pop.length >= 6 ? SetupCode(pop: pop) : null;
  }
}

class ProvisionableBridge {
  const ProvisionableBridge({required this.id, required this.name});

  /// Plattform-ID des Bluetooth-Geräts.
  final String id;

  /// Bluetooth-Name, z. B. `Ruehrlink-98C0`.
  final String name;
}

/// Antwort von `rl-info`.
class BridgeSetupInfo {
  const BridgeSetupInfo({
    required this.id,
    required this.name,
    required this.fw,
    required this.host,
    required this.homeConfigured,
    required this.homeConnected,
    this.homeSsid = '',
    this.homeError,
  });

  final String id;
  final String name;
  final String fw;

  /// mDNS-Name, z. B. `ruehrlink-98c0.local`.
  final String host;
  final bool homeConfigured;
  final bool homeConnected;
  final String homeSsid;

  /// `auth`, `not_found`, `other` oder `null`.
  final String? homeError;

  factory BridgeSetupInfo.fromJson(Json j) {
    final home = readMap(j['home']);
    return BridgeSetupInfo(
      id: readString(j['id']),
      name: readString(j['name']),
      fw: readString(j['fw']),
      host: readString(j['host']),
      homeConfigured: readBool(home['configured']),
      homeConnected: readBool(home['connected']),
      homeSsid: readString(home['ssid']),
      homeError: home['error'] as String?,
    );
  }
}

class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.signal,
    required this.secured,
  });

  /// Aus `rl-scan`: `{"ssid","rssi","secure"}`.
  factory WifiNetwork.fromJson(Json j) {
    final rssi = readInt(j['rssi'], -100);
    return WifiNetwork(
      ssid: readString(j['ssid']),
      signal: rssi >= -55
          ? 3
          : rssi >= -67
          ? 2
          : rssi >= -78
          ? 1
          : 0,
      secured: readBool(j['secure'], true),
    );
  }

  final String ssid;

  /// Empfangsstärke 0 (schwach) bis 3 (sehr gut).
  final int signal;
  final bool secured;
}

enum ProvisioningError {
  /// Bluetooth ist aus.
  bluetoothOff,

  /// Bluetooth- oder Kamera-Berechtigung verweigert.
  permissionDenied,

  /// Brücke nicht gefunden / Verbindung nicht möglich.
  notFound,

  /// Code vom Etikett falsch.
  wrongPin,

  /// WLAN-Passwort falsch.
  wrongPassword,

  /// WLAN nicht gefunden / außer Reichweite.
  wifiNotFound,

  /// WLAN-Verbindung aus anderem Grund gescheitert (oder Zeitüberschreitung).
  wifiFailed,

  /// Verbindung zur Brücke abgebrochen / unerwartete Antwort.
  connectionLost,
}

class ProvisioningException implements Exception {
  const ProvisioningException(this.error, [this.detail]);
  final ProvisioningError error;

  /// Technische Einzelheit für die Entwicklerdetails.
  final String? detail;

  @override
  String toString() =>
      'ProvisioningException(${error.name}${detail == null ? '' : ': $detail'})';
}

/// Echte Bluetooth-Einrichtung. Tests und Demo überschreiben diesen Provider
/// mit `FakeBridgeProvisioning`.
final bridgeProvisioningProvider = Provider<BridgeProvisioning>((ref) {
  final p = BleBridgeProvisioning(
    log: ref.watch(provisioningLogProvider),
    discovery: ref.watch(bridgeDiscoveryProvider),
  );
  ref.onDispose(() => p.disconnect());
  return p;
});
