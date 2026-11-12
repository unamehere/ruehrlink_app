import '../models/models.dart';
import 'bridge_provisioning.dart';

/// Simulierte Bluetooth-Einrichtung. Endet im Demo-Modus.
///
/// Zum Ausprobieren der Fehlerwege: PIN `0000` ist falsch, WLAN-Passwort
/// `falsch` ebenso.
class FakeBridgeProvisioning implements BridgeProvisioning {
  FakeBridgeProvisioning({this.latency = const Duration(milliseconds: 800)});

  final Duration latency;

  Future<void> _wait([int factor = 1]) => Future.delayed(latency * factor);

  @override
  Stream<List<ProvisionableBridge>> scan() async* {
    yield const [];
    await _wait(2);
    yield const [ProvisionableBridge(id: '98C0', name: 'Freikoch-98C0')];
  }

  @override
  Future<void> connect(
    ProvisionableBridge bridge, {
    required String pin,
  }) async {
    await _wait();
    if (pin.trim().isEmpty || pin.trim() == '0000') {
      throw const ProvisioningException(ProvisioningError.wrongPin);
    }
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
  }

  @override
  Future<BridgeTarget> finish() async {
    await _wait();
    return const DemoTarget();
  }

  @override
  Future<void> disconnect() async {}
}
