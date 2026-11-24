import '../models/models.dart';
import 'bridge_provisioning.dart';
import 'diag_log.dart';

/// Simulierte Bluetooth-Einrichtung für Tests und Vorführung. Endet im Demo-Modus.
///
/// Zum Ausprobieren der Fehlerwege: Code `000000` ist falsch, WLAN-Passwort
/// `falsch` ebenso, das Netz „Nachbar“ wird nicht gefunden.
class FakeBridgeProvisioning implements BridgeProvisioning {
  FakeBridgeProvisioning({
    this.latency = const Duration(milliseconds: 800),
    this.homeConnected = false,
    DiagLog? log,
  }) : log = log ?? DiagLog();

  final Duration latency;

  /// Brücke ist schon im Heim-WLAN (WLAN-Schritt entfällt).
  bool homeConnected;
  final DiagLog log;

  Future<void> _wait([int factor = 1]) => Future.delayed(latency * factor);

  @override
  Stream<List<ProvisionableBridge>> scan() async* {
    log.add('Demo: Suche Ruehrlink-…');
    yield const [];
    await _wait(2);
    yield const [ProvisionableBridge(id: 'demo', name: 'Ruehrlink-98C0')];
  }

  @override
  Future<void> connect(
    ProvisionableBridge bridge, {
    required SetupCode code,
  }) async {
    await _wait();
    if (code.pop == '000000') {
      log.add('Demo: Sitzung abgelehnt');
      throw const ProvisioningException(
        ProvisioningError.wrongPin,
        'Demo: Code 000000',
      );
    }
    log.add('Demo: Sitzung steht');
  }

  @override
  Future<BridgeSetupInfo> info() async {
    await _wait();
    return BridgeSetupInfo(
      id: '98C0',
      name: 'Rührlink',
      fw: '0.1.0',
      host: 'ruehrlink-98c0.local',
      homeConfigured: homeConnected,
      homeConnected: homeConnected,
      homeSsid: homeConnected ? 'Zuhause' : '',
    );
  }

  @override
  Future<List<WifiNetwork>> scanWifi() async {
    await _wait(2);
    return const [
      WifiNetwork(ssid: 'Zuhause', signal: 3, secured: true),
      WifiNetwork(ssid: 'Zuhause-Gast', signal: 2, secured: true),
      WifiNetwork(ssid: 'Nachbar', signal: 1, secured: true),
    ];
  }

  @override
  Future<void> joinWifi(String ssid, String password) async {
    await _wait(3);
    if (password == 'falsch') {
      throw const ProvisioningException(ProvisioningError.wrongPassword);
    }
    if (ssid == 'Nachbar') {
      throw const ProvisioningException(ProvisioningError.wifiNotFound);
    }
    homeConnected = true;
  }

  @override
  Future<BridgeTarget> finish() async {
    await _wait();
    return const DemoTarget();
  }

  @override
  Future<void> disconnect() async {}
}
