import 'dart:convert';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointycastle/export.dart';

import '../../version.dart';
import '../api/bridge_providers.dart';
import '../models/json.dart';
import '../models/models.dart';

/// Öffentlicher Schlüssel für Firmware-Updates (ECDSA P-256, unkomprimiert) – derselbe wie in
/// `ruehrlink_esp/firmware/components/update/signing_pubkey.h`. Die App prüft damit vorab,
/// der Rührlink prüft beim Update selbst noch einmal.
const _signingPubkey =
    '040a97d39f810b27eaa66172dcb6a1c1a0ba71953f21c96d605e36db15d575cd97'
    '710b973fd865b0afc47e028e5b70ddee2005b9a2cc96b65c5cbfd4698e99c0bb';

/// Manifest einer Update-Datei `.rlfw` (ZIP aus manifest.json + Image, erzeugt von
/// `ruehrlink_esp/tools/firmware_sign.py pack`). Aufbau und Regeln: `ruehrlink_esp/docs/updates.md`.
class FirmwareManifest {
  const FirmwareManifest({
    required this.version,
    required this.api,
    required this.minApp,
    required this.channel,
    required this.security,
    required this.notes,
    required this.file,
    required this.size,
    required this.sha256,
    required this.sig,
  });

  final String version;

  /// API-Hauptversion, die diese Firmware spricht.
  final int api;

  /// Älteste App, die mit dieser Firmware zurechtkommt.
  final String minApp;

  /// `stable` oder `beta` (nur Anzeige).
  final String channel;

  /// Sicherheitsupdate → deutlicher Hinweis.
  final bool security;

  /// Änderungsnotizen für Nutzer.
  final String notes;
  final String file;
  final int size;

  /// SHA-256 des Images, hex.
  final String sha256;

  /// ECDSA-Signatur (r||s), hex.
  final String sig;

  factory FirmwareManifest.fromJson(Json j) => FirmwareManifest(
    version: readString(j['version']),
    api: readInt(j['api'], 1),
    minApp: readString(j['minApp'], '0.0.0'),
    channel: readString(j['channel'], 'stable'),
    security: readBool(j['security']),
    notes: readString(j['notes']).trim(),
    file: readString(j['file']),
    size: readInt(j['size']),
    sha256: readString(j['sha256']).toLowerCase(),
    sig: readString(j['sig']).toLowerCase(),
  );
}

/// Warum eine Update-Datei nicht passt.
enum FirmwareFileError {
  /// Keine `.rlfw`-Datei (kein ZIP, Manifest fehlt oder unvollständig).
  invalid,

  /// Größe oder SHA-256 stimmen nicht – Datei beschädigt.
  damaged,

  /// Signatur passt nicht – nicht von uns.
  signature,

  /// Firmware braucht eine neuere App (`minApp`, `api`).
  appTooOld,
}

class FirmwareFileException implements Exception {
  const FirmwareFileException(this.error);

  final FirmwareFileError error;

  @override
  String toString() => 'FirmwareFileException($error)';
}

/// Eine geprüfte Update-Datei: Manifest + Image.
class FirmwarePackage {
  const FirmwarePackage(this.manifest, this.image);

  final FirmwareManifest manifest;
  final Uint8List image;

  /// Nur das Manifest lesen (ohne Prüfung) – z. B. um die Version der eingebauten Firmware zu kennen.
  static FirmwareManifest readManifest(Uint8List rlfw) {
    final Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(rlfw);
    } on Object {
      throw const FirmwareFileException(FirmwareFileError.invalid);
    }
    final entry = zip.findFile('manifest.json');
    if (entry == null) {
      throw const FirmwareFileException(FirmwareFileError.invalid);
    }
    try {
      final m = FirmwareManifest.fromJson(
        readMap(jsonDecode(utf8.decode(entry.content))),
      );
      if (m.version.isEmpty || m.file.isEmpty || m.sig.length != 128) {
        throw const FirmwareFileException(FirmwareFileError.invalid);
      }
      return m;
    } on FormatException {
      throw const FirmwareFileException(FirmwareFileError.invalid);
    }
  }

  /// Update-Datei entpacken und vollständig prüfen: Manifest, Größe, SHA-256, Signatur,
  /// `minApp` und `api`. Läuft in einem eigenen Isolate (das Image hat ~1,5 MB).
  static Future<FirmwarePackage> open(Uint8List rlfw) =>
      Isolate.run(() => verify(rlfw));

  /// Wie [open], aber synchron (für Tests).
  static FirmwarePackage verify(Uint8List rlfw, {String app = appVersion}) {
    final m = readManifest(rlfw);
    final entry = ZipDecoder().decodeBytes(rlfw).findFile(m.file);
    if (entry == null) {
      throw const FirmwareFileException(FirmwareFileError.invalid);
    }
    final image = Uint8List.fromList(entry.content);
    if (image.length != m.size ||
        crypto.sha256.convert(image).toString() != m.sha256) {
      throw const FirmwareFileException(FirmwareFileError.damaged);
    }
    if (!_signatureOk(image, m.sig)) {
      throw const FirmwareFileException(FirmwareFileError.signature);
    }
    if (compareVersions(app, m.minApp) < 0 || !appApis.contains(m.api)) {
      throw const FirmwareFileException(FirmwareFileError.appTooOld);
    }
    return FirmwarePackage(m, image);
  }

  static bool _signatureOk(Uint8List image, String sigHex) {
    final curve = ECCurve_secp256r1();
    final point = curve.curve.decodePoint(_hex(_signingPubkey));
    final signer = ECDSASigner(SHA256Digest())
      ..init(false, PublicKeyParameter(ECPublicKey(point, curve)));
    BigInt big(String h) => BigInt.parse(h, radix: 16);
    return signer.verifySignature(
      image,
      ECSignature(big(sigHex.substring(0, 64)), big(sigHex.substring(64))),
    );
  }

  static Uint8List _hex(String h) => Uint8List.fromList([
    for (var i = 0; i < h.length; i += 2)
      int.parse(h.substring(i, i + 2), radix: 16),
  ]);
}

/// Die Firmware, die diese App mitbringt (`assets/firmware/ruehrlink-<version>.rlfw`), als
/// Rückfall z. B. für neue Rührlinks mit alter Werks-Firmware.
class BundledFirmware {
  const BundledFirmware(this.asset, this.manifest);

  static const _dir = 'assets/firmware/';

  final String asset;
  final FirmwareManifest manifest;

  /// `null`, wenn diese App ohne Firmware gebaut wurde (Entwicklung).
  static Future<BundledFirmware?> load() async {
    try {
      final assets = (await AssetManifest.loadFromAssetBundle(rootBundle))
          .listAssets();
      final asset = assets
          .where((a) => a.startsWith(_dir) && a.endsWith('.rlfw'))
          .firstOrNull;
      if (asset == null) return null;
      return BundledFirmware(
        asset,
        FirmwarePackage.readManifest(await _bytes(asset)),
      );
    } on Exception {
      return null;
    }
  }

  Future<Uint8List> bytes() => _bytes(asset);

  static Future<Uint8List> _bytes(String asset) async {
    final data = await rootBundle.load(asset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}

/// Vergleicht `0.1.12` mit `0.2.0` Zahl für Zahl (Zusätze wie `-dirty` werden ignoriert).
int compareVersions(String a, String b) {
  List<int> split(String v) => v
      .split(RegExp(r'[^0-9.]'))
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final x = split(a), y = split(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

final bundledFirmwareProvider = FutureProvider<BundledFirmware?>(
  (ref) => BundledFirmware.load(),
);

/// Ist die eingebaute Firmware neuer als die des Rührlink? Dann dezent auf das Update hinweisen.
/// Abgefragt wird nirgends – neue Firmware holt sich der Nutzer selbst (GitHub-Release).
final bundledUpdateProvider = Provider<FirmwareManifest?>((ref) {
  if (ref.watch(bridgeTargetProvider) is DemoTarget) return null;
  final info = ref.watch(bridgeInfoProvider).value;
  final bundled = ref.watch(bundledFirmwareProvider).value?.manifest;
  if (info == null || bundled == null || info.fw.isEmpty) return null;
  return compareVersions(bundled.version, info.fw) > 0 ? bundled : null;
});
