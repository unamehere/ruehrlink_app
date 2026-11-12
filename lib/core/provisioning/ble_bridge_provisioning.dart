import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import '../discovery/bridge_discovery.dart';
import '../models/json.dart';
import '../models/models.dart';
import 'bridge_provisioning.dart';
import 'diag_log.dart';
import 'sec2/sec2_session.dart';

/// Bluetooth-Einrichtung gegen die echte Brücke (ESP-IDF `network_provisioning`,
/// Modus SESSION_ONLY, Security 2) – reines Dart über `universal_ble`.
///
/// Jeder Endpunkt ist eine GATT-Charakteristik des Provisioning-Dienstes; ihr
/// Name steht im User-Description-Deskriptor (0x2901). Ein Aufruf = Schreiben
/// (mit Antwort) und danach Lesen derselben Charakteristik.
class BleBridgeProvisioning implements BridgeProvisioning {
  BleBridgeProvisioning({required this.log, required this.discovery});

  final DiagLog log;
  final BridgeDiscovery discovery;

  static const namePrefix = 'Freikoch-';

  /// Standard-Dienst von ESP-IDF `network_provisioning` (Fallback, falls die
  /// Deskriptoren nicht lesbar sind, wird darüber gesucht).
  static const defaultServiceUuid = '1775244d-6b43-439b-877c-060f2d9bed07';
  static const _userDescription = '2901';
  static const _required = ['prov-session', 'fk-info', 'fk-token'];

  String? _deviceId;
  BridgeSetupInfo? _info;
  Sec2Session? _session;

  /// Endpunkt-Name → (Dienst, Charakteristik).
  final _endpoints = <String, (String, String)>{};

  // ---------------------------------------------------------------- Suche

  Future<void> _ensureBluetooth() async {
    try {
      await UniversalBle.requestPermissions();
    } catch (e) {
      log.add('Berechtigung verweigert: $e');
      throw ProvisioningException(ProvisioningError.permissionDenied, '$e');
    }
    final state = await UniversalBle.getBluetoothAvailabilityState();
    log.add('Bluetooth: ${state.name}');
    if (state == AvailabilityState.unauthorized) {
      throw const ProvisioningException(ProvisioningError.permissionDenied);
    }
    if (state != AvailabilityState.poweredOn) {
      throw ProvisioningException(ProvisioningError.bluetoothOff, state.name);
    }
  }

  @override
  Stream<List<ProvisionableBridge>> scan() {
    final found = <String, ProvisionableBridge>{};
    late final StreamController<List<ProvisionableBridge>> out;
    StreamSubscription<BleDevice>? sub;

    Future<void> start() async {
      await _ensureBluetooth();
      log.add('Suche $namePrefix…');
      sub = UniversalBle.scanStream.listen((d) {
        final name = d.name ?? '';
        if (!name.startsWith(namePrefix) || found.containsKey(d.deviceId)) {
          return;
        }
        log.add('Gefunden: $name (RSSI ${d.rssi})');
        found[d.deviceId] = ProvisionableBridge(id: d.deviceId, name: name);
        if (!out.isClosed) out.add(List.unmodifiable(found.values));
      });
      await UniversalBle.startScan(
        scanFilter: ScanFilter(withNamePrefix: const [namePrefix]),
      );
    }

    out = StreamController(
      onListen: () {
        out.add(const []);
        start().catchError((Object e) {
          if (!out.isClosed) out.addError(e);
        });
      },
      onCancel: () async {
        await sub?.cancel();
        try {
          await UniversalBle.stopScan();
        } catch (_) {}
      },
    );
    return out.stream;
  }

  // ------------------------------------------------------------ Verbindung

  @override
  Future<void> connect(
    ProvisionableBridge bridge, {
    required SetupCode code,
  }) async {
    await disconnect();
    final id = bridge.id;
    try {
      log.add('Verbinde mit ${bridge.name}…');
      await UniversalBle.connect(id, timeout: const Duration(seconds: 20));
      _deviceId = id;
      try {
        final mtu = await UniversalBle.requestMtu(id, 517);
        log.add('MTU $mtu');
      } catch (e) {
        log.add('MTU nicht gesetzt: $e');
      }
      await _discoverEndpoints(id);
    } on ProvisioningException {
      rethrow;
    } catch (e) {
      log.add('Verbindung fehlgeschlagen: $e');
      throw ProvisioningException(ProvisioningError.notFound, '$e');
    }

    // Version und Sicherheitsstufe (unverschlüsselt).
    var patch = 1;
    if (_endpoints.containsKey('proto-ver')) {
      try {
        final ver = utf8.decode(await _raw('proto-ver', utf8.encode('ESP')));
        log.add('proto-ver: $ver');
        final prov = readMap(readMap(jsonDecode(ver))['prov']);
        final sec = readInt(prov['sec_ver'], 2);
        patch = readInt(prov['sec_patch_ver'], 0);
        if (sec != 2) {
          throw ProvisioningException(
            ProvisioningError.connectionLost,
            'Sicherheitsstufe $sec statt 2',
          );
        }
      } on ProvisioningException {
        rethrow;
      } catch (e) {
        log.add('proto-ver unlesbar: $e (nehme Patch 1)');
      }
    }

    // Security-2-Handshake.
    final session = Sec2Session(
      username: code.username,
      pop: code.pop,
      patchVersion: patch,
    );
    var step = 1;
    try {
      log.add('Sitzung: Schritt 1 (SRP6a, Benutzer ${code.username})');
      session.response0(await _raw('prov-session', session.command0()));
      step = 2;
      log.add('Sitzung: Schritt 2');
      session.response1(await _raw('prov-session', session.command1()));
      _session = session;
      log.add('Sitzung steht (AES-256-GCM, Patch $patch)');
    } on Sec2Exception catch (e) {
      log.add('Sitzung abgelehnt (Schritt $step): $e');
      await disconnect();
      throw ProvisioningException(
        step == 2
            ? ProvisioningError.wrongPin
            : ProvisioningError.connectionLost,
        e.message,
      );
    } on ProvisioningException catch (e) {
      // Bei falschem Code bricht die Brücke den Schritt 2 ab (GATT-Fehler).
      log.add('Sitzung abgebrochen (Schritt $step): ${e.detail}');
      await disconnect();
      throw ProvisioningException(
        step == 2
            ? ProvisioningError.wrongPin
            : ProvisioningError.connectionLost,
        e.detail,
      );
    }
  }

  Future<void> _discoverEndpoints(String id) async {
    final services = await UniversalBle.discoverServices(
      id,
      withDescriptors: true,
    );
    _endpoints.clear();
    for (final s in services) {
      for (final c in s.characteristics) {
        final hasName = c.descriptors.any(
          (d) => d.uuid.toLowerCase().contains(_userDescription),
        );
        if (!hasName) continue;
        try {
          final raw = await UniversalBle.readDescriptor(
            id,
            s.uuid,
            c.uuid,
            _userDescription,
          );
          final name = utf8.decode(raw, allowMalformed: true).trim();
          _endpoints[name.replaceAll('\u0000', '')] = (s.uuid, c.uuid);
        } catch (e) {
          log.add('Deskriptor ${c.uuid} unlesbar: $e');
        }
      }
    }
    log.add('Endpunkte: ${_endpoints.keys.join(', ')}');
    final missing = _required.where((e) => !_endpoints.containsKey(e));
    if (missing.isNotEmpty) {
      final hasService = services.any(
        (s) => s.uuid.toLowerCase() == defaultServiceUuid,
      );
      throw ProvisioningException(
        ProvisioningError.notFound,
        'fehlt: ${missing.join(', ')} '
        '(Dienst ${hasService ? 'vorhanden' : 'nicht gefunden'})',
      );
    }
  }

  /// Rohaufruf eines Endpunkts: schreiben, dann lesen.
  Future<Uint8List> _raw(String endpoint, List<int> data) async {
    final id = _deviceId;
    final ep = _endpoints[endpoint];
    if (id == null || ep == null) {
      throw ProvisioningException(
        ProvisioningError.connectionLost,
        'kein Endpunkt $endpoint',
      );
    }
    try {
      await UniversalBle.write(id, ep.$1, ep.$2, Uint8List.fromList(data));
      final r = await UniversalBle.read(id, ep.$1, ep.$2);
      if (r.isEmpty) throw StateError('leere Antwort');
      return r;
    } catch (e) {
      throw ProvisioningException(
        ProvisioningError.connectionLost,
        '$endpoint: $e',
      );
    }
  }

  /// Verschlüsselter JSON-Aufruf eines fk-Endpunkts.
  Future<Json> _call(String endpoint, [Json body = const {}]) async {
    final session = _session;
    if (session == null) {
      throw const ProvisioningException(
        ProvisioningError.connectionLost,
        'keine Sitzung',
      );
    }
    final request = session.encrypt(
      Uint8List.fromList(utf8.encode(jsonEncode(body))),
    );
    final response = await _raw(endpoint, request);
    try {
      return readMap(jsonDecode(utf8.decode(session.decrypt(response))));
    } on Sec2Exception catch (e) {
      throw ProvisioningException(
        ProvisioningError.connectionLost,
        '$endpoint: $e',
      );
    } on FormatException catch (e) {
      throw ProvisioningException(
        ProvisioningError.connectionLost,
        '$endpoint: kein JSON (${e.message})',
      );
    }
  }

  // -------------------------------------------------------------- Endpunkte

  @override
  Future<BridgeSetupInfo> info() async {
    final info = BridgeSetupInfo.fromJson(await _call('fk-info'));
    _info = info;
    log.add(
      'fk-info: ${info.id} fw ${info.fw}, WLAN '
      '${info.homeConnected ? 'verbunden' : (info.homeConfigured ? 'eingerichtet' : 'leer')}'
      '${info.homeError == null ? '' : ' (Fehler ${info.homeError})'}',
    );
    return info;
  }

  @override
  Future<List<WifiNetwork>> scanWifi() async {
    // Die Brücke sucht im Hintergrund (eine blockierende Suche würde Bluetooth
    // stören): erster Aufruf startet die Suche, danach nachfragen, bis
    // `scanning` false ist – max. 15 s.
    log.add('fk-scan…');
    var j = await _call('fk-scan', const {'refresh': true});
    for (var i = 0; i < 15 && j['scanning'] == true; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      j = await _call('fk-scan');
    }
    // Seitenweise abholen: eine BLE-Antwort darf max. 512 Byte haben.
    final list = <WifiNetwork>[...readList(j['networks'], WifiNetwork.fromJson)];
    final total = (j['total'] as num?)?.toInt() ?? list.length;
    while (list.length < total) {
      final page = await _call('fk-scan', {'start': list.length});
      final more = readList(page['networks'], WifiNetwork.fromJson);
      if (more.isEmpty) break;
      list.addAll(more);
    }
    log.add('fk-scan: ${list.length} Netze${j['scanning'] == true ? ' (Suche läuft noch)' : ''}');
    return list;
  }

  @override
  Future<void> joinWifi(String ssid, String password) async {
    log.add('fk-wifi: „$ssid“');
    final r = await _call('fk-wifi', {'ssid': ssid, 'password': password});
    if (!readBool(r['ok'])) {
      throw const ProvisioningException(
        ProvisioningError.wifiFailed,
        'fk-wifi ok=false',
      );
    }
    // Ergebnis per fk-info abfragen (alle 1,5 s, max. 30 s).
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final info = await this.info();
      if (info.homeConnected) return;
      switch (info.homeError) {
        case 'auth':
          throw const ProvisioningException(ProvisioningError.wrongPassword);
        case 'not_found':
          throw const ProvisioningException(ProvisioningError.wifiNotFound);
        case 'other':
          throw const ProvisioningException(
            ProvisioningError.wifiFailed,
            'home.error=other',
          );
      }
    }
    throw const ProvisioningException(
      ProvisioningError.wifiFailed,
      'keine Verbindung nach 30 s',
    );
  }

  @override
  Future<BridgeTarget> finish() async {
    final info = _info ?? await this.info();
    final token = readString((await _call('fk-token'))['token']);
    if (token.isEmpty) {
      throw const ProvisioningException(
        ProvisioningError.connectionLost,
        'fk-token leer',
      );
    }
    log.add('Token erhalten');
    await disconnect();

    // IP über mDNS suchen (Android löst „.local“ nicht zuverlässig auf).
    var host = info.host;
    var port = 80;
    try {
      log.add('Suche ${info.id} im WLAN (mDNS)…');
      final match = await discovery
          .scan()
          .expand((list) => list)
          .firstWhere((b) => b.id.toUpperCase() == info.id.toUpperCase())
          .timeout(const Duration(seconds: 10));
      host = match.host;
      port = match.port;
      log.add('Im WLAN: $host:$port');
    } catch (e) {
      log.add('mDNS ohne Treffer ($e) – nehme ${info.host}');
    }
    return NetworkTarget(
      host: host,
      port: port,
      token: token,
      id: info.id,
      name: info.name,
    );
  }

  @override
  Future<void> disconnect() async {
    final id = _deviceId;
    _deviceId = null;
    _session = null;
    if (id == null) return;
    try {
      await UniversalBle.disconnect(id);
      log.add('Bluetooth getrennt');
    } catch (_) {}
  }
}
