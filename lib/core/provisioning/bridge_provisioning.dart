import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'fake_bridge_provisioning.dart';

/// Einrichtung einer neuen Brücke per Bluetooth (ESP-IDF `network_provisioning`,
/// Security 2). Ablauf siehe `freikoch_esp/docs/architektur.md`:
///
/// 1. [scan] findet Brücken im Einrichtungsmodus (`Freikoch-XXXX`).
/// 2. [connect] öffnet mit dem PIN vom QR-Etikett eine verschlüsselte Sitzung.
/// 3. [scanWifi] lässt die Brücke Heim-WLANs suchen.
/// 4. [joinWifi] übergibt WLAN und Passwort; wirft [ProvisioningException] bei Fehler.
/// 5. [finish] holt über den Endpunkt `freikoch` Token und Namen und liefert
///    das Ziel, mit dem die App die Brücke danach im WLAN anspricht.
///
/// Die echte BLE-Anbindung (Paketwahl) folgt; bis dahin gibt es nur den Fake.
abstract class BridgeProvisioning {
  Stream<List<ProvisionableBridge>> scan();

  Future<void> connect(ProvisionableBridge bridge, {required String pin});

  Future<List<WifiNetwork>> scanWifi();

  Future<void> joinWifi(String ssid, String password);

  Future<BridgeTarget> finish();

  /// Sitzung beenden (auch bei Abbruch).
  Future<void> disconnect();
}

class ProvisionableBridge {
  const ProvisionableBridge({required this.id, required this.name});

  final String id;

  /// Bluetooth-Name, z. B. `Freikoch-98C0`.
  final String name;
}

class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.signal,
    required this.secured,
  });

  final String ssid;

  /// Empfangsstärke 0 (schwach) bis 3 (sehr gut).
  final int signal;
  final bool secured;
}

enum ProvisioningError {
  /// PIN falsch oder Sitzung nicht möglich.
  wrongPin,

  /// WLAN-Passwort falsch.
  wrongPassword,

  /// WLAN nicht gefunden / außer Reichweite.
  wifiNotFound,

  /// Verbindung zur Brücke abgebrochen.
  connectionLost,
}

class ProvisioningException implements Exception {
  const ProvisioningException(this.error);
  final ProvisioningError error;

  @override
  String toString() => 'ProvisioningException($error)';
}

/// Bis die BLE-Anbindung steht, liefert dieser Provider den Fake.
final bridgeProvisioningProvider = Provider<BridgeProvisioning>(
  (ref) => FakeBridgeProvisioning(),
);
