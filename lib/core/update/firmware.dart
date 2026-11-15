import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/bridge_providers.dart';
import '../models/json.dart';
import '../models/models.dart';

/// Die Firmware, die diese App mitbringt (`assets/firmware/manifest.json`, erzeugt von
/// `freikoch_esp/tools/firmware_sign.py`). Ablauf: `freikoch_esp/docs/updates.md`.
class FirmwareManifest {
  const FirmwareManifest({
    required this.version,
    required this.api,
    required this.file,
    required this.size,
    required this.sha256,
    required this.sig,
  });

  final String version;
  final int api;
  final String file;
  final int size;

  /// SHA-256 des Images, hex.
  final String sha256;

  /// ECDSA-Signatur (r||s), hex – prüft die Brücke.
  final String sig;

  factory FirmwareManifest.fromJson(Json j) => FirmwareManifest(
    version: readString(j['version']),
    api: readInt(j['api'], 1),
    file: readString(j['file']),
    size: readInt(j['size']),
    sha256: readString(j['sha256']),
    sig: readString(j['sig']),
  );

  static const _dir = 'assets/firmware';

  /// `null`, wenn diese App ohne Firmware gebaut wurde (Entwicklung).
  static Future<FirmwareManifest?> loadBundled() async {
    try {
      final m = FirmwareManifest.fromJson(
        readMap(jsonDecode(await rootBundle.loadString('$_dir/manifest.json'))),
      );
      return m.version.isEmpty || m.file.isEmpty ? null : m;
    } on Exception {
      return null;
    } on Error {
      return null; // FlutterError: Asset fehlt
    }
  }

  Future<Uint8List> loadImage() async {
    final data = await rootBundle.load('$_dir/$file');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}

/// Vergleicht `0.1.12` mit `0.2.0` Zahl für Zahl (Zusätze wie `-dirty` werden ignoriert).
/// [parts] = 2 vergleicht nur `MAJOR.MINOR`.
int compareVersions(String a, String b, {int parts = 3}) {
  List<int> split(String v) => v
      .split(RegExp(r'[^0-9.]'))
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final x = split(a), y = split(b);
  for (var i = 0; i < parts; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

final bundledFirmwareProvider = FutureProvider<FirmwareManifest?>(
  (ref) => FirmwareManifest.loadBundled(),
);

enum FirmwareCheck {
  /// Passt: gleiche Version, oder die Brücke hat nur einen neueren Bugfix (Patch).
  current,

  /// Gleiches `MAJOR.MINOR`, Brücke hat einen älteren Patch → Bugfix-Update anbieten, kein Muss.
  bugfix,

  /// `MAJOR.MINOR` der Brücke älter → Update nötig, die Funktionen passen sonst nicht zusammen.
  bridgeOlder,

  /// `MAJOR.MINOR` der Brücke neuer (z. B. von einem anderen Handy aktualisiert) → App aktualisieren.
  bridgeNewer,
}

final firmwareCheckProvider = Provider<FirmwareCheck>((ref) {
  if (ref.watch(bridgeTargetProvider) is DemoTarget) {
    return FirmwareCheck.current;
  }
  final info = ref.watch(bridgeInfoProvider).value;
  final bundled = ref.watch(bundledFirmwareProvider).value;
  if (info == null || bundled == null || info.fw.isEmpty) {
    return FirmwareCheck.current;
  }
  // Regeln: freikoch_esp/docs/updates.md – MAJOR.MINOR muss passen, der Patch nicht.
  return switch (compareVersions(info.fw, bundled.version, parts: 2)) {
    < 0 => FirmwareCheck.bridgeOlder,
    > 0 => FirmwareCheck.bridgeNewer,
    _ when compareVersions(info.fw, bundled.version) < 0 =>
      FirmwareCheck.bugfix,
    _ => FirmwareCheck.current,
  };
});
