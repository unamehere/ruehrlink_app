import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'protobuf.dart';
import 'srp6a.dart';

/// ESP-IDF protocomm „Security 2“ aus Sicht der App: SRP6a-Handshake über den
/// Endpunkt `prov-session`, danach AES-256-GCM für alle anderen Endpunkte.
///
/// Nachrichten (session.proto / sec2.proto):
/// `SessionData { sec_ver = 2; sec2 = Sec2Payload { msg; sc0|sr0|sc1|sr1 } }`.
///
/// Nonce: 12 Byte von der Brücke; ab `sec_patch_ver` 1 werden die letzten vier
/// Byte (Big-Endian-Zähler) nach JEDER Ver- und Entschlüsselung erhöht – auf
/// beiden Seiten gemeinsam, d. h. Anfrage n, Antwort n+1, nächste Anfrage n+2.
class Sec2Session {
  Sec2Session({
    required String username,
    required String pop,
    this.patchVersion = 1,
    SrpClient? srp,
  }) : _srp = srp ?? SrpClient(username: username, password: pop),
       _username = username;

  final int patchVersion;
  final SrpClient _srp;
  final String _username;
  Uint8List? _proof;
  Uint8List? _key;
  Uint8List? _nonce;

  static const _secScheme2 = 2;
  // Sec2MsgType
  static const _cmd0 = 0, _resp0 = 1, _cmd1 = 2, _resp1 = 3;

  bool get established => _key != null;

  Uint8List _sessionData(int msg, int payloadField, Uint8List payload) {
    final sec2 = ProtoWriter()
      ..int32(1, msg)
      ..bytes(payloadField, payload);
    return (ProtoWriter()
          ..int32(2, _secScheme2)
          ..bytes(12, sec2.toBytes()))
        .toBytes();
  }

  /// Liest SessionData und liefert den Sec2-Payload des erwarteten Typs.
  Map<int, Object> _payload(Uint8List data, int msg, int field) {
    final session = readProto(data);
    final ver = session[2] ?? 0;
    if (ver != _secScheme2) {
      throw Sec2Exception('Falsches Sicherheitsschema ($ver)');
    }
    final sec2 = session[12];
    if (sec2 is! Uint8List) throw const Sec2Exception('Antwort ohne sec2');
    final p = readProto(sec2);
    if ((p[1] ?? 0) != msg) {
      throw Sec2Exception('Unerwartete Nachricht ${p[1]}');
    }
    final inner = p[field];
    if (inner is! Uint8List) throw const Sec2Exception('Antwort ohne Inhalt');
    final fields = readProto(inner);
    final status = fields[1] ?? 0;
    if (status != 0) {
      throw Sec2Exception('Status $status', status: status as int);
    }
    return fields;
  }

  /// Schritt 1: Benutzername + öffentlicher Schlüssel A.
  Uint8List command0() => _sessionData(
    _cmd0,
    20,
    (ProtoWriter()
          ..bytes(1, utf8.encode(_username))
          ..bytes(2, _srp.publicKey))
        .toBytes(),
  );

  /// Antwort 1: B + Salt der Brücke → Beweis M berechnen.
  void response0(Uint8List data) {
    final f = _payload(data, _resp0, 21);
    final b = f[2], salt = f[3];
    if (b is! Uint8List || salt is! Uint8List) {
      throw const Sec2Exception('Antwort 0 unvollständig');
    }
    _proof = _srp.processChallenge(salt, b);
  }

  /// Schritt 2: Client-Beweis M.
  Uint8List command1() {
    final proof = _proof;
    if (proof == null) throw StateError('response0 fehlt');
    return _sessionData(_cmd1, 22, (ProtoWriter()..bytes(1, proof)).toBytes());
  }

  /// Antwort 2: Beweis der Brücke prüfen, Schlüssel und Nonce übernehmen.
  void response1(Uint8List data) {
    final f = _payload(data, _resp1, 23);
    final proof = f[2], nonce = f[3];
    if (proof is! Uint8List || nonce is! Uint8List || nonce.length != 12) {
      throw const Sec2Exception('Antwort 1 unvollständig');
    }
    if (!_srp.verifyServerProof(proof)) {
      throw const Sec2Exception('Beweis des Rührlinks ungültig');
    }
    _key = Uint8List.fromList(_srp.sessionKey.sublist(0, 32));
    _nonce = Uint8List.fromList(nonce);
  }

  /// Nur für Tests: Sitzung mit bekanntem Schlüssel und Nonce.
  Sec2Session.established(
    Uint8List key,
    Uint8List nonce, {
    this.patchVersion = 1,
  }) : _srp = SrpClient(username: '', password: ''),
       _username = '',
       _key = key,
       _nonce = Uint8List.fromList(nonce);

  Uint8List encrypt(Uint8List plain) => _crypt(true, plain);

  Uint8List decrypt(Uint8List data) => _crypt(false, data);

  Uint8List _crypt(bool forEncryption, Uint8List input) {
    final key = _key, nonce = _nonce;
    if (key == null || nonce == null) throw StateError('Keine Sitzung');
    final gcm = GCMBlockCipher(AESEngine())
      ..init(
        forEncryption,
        AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)),
      );
    final Uint8List out;
    try {
      out = gcm.process(input);
    } on InvalidCipherTextException {
      throw const Sec2Exception('Entschlüsselung fehlgeschlagen');
    }
    if (patchVersion >= 1) _incrementNonce(nonce);
    return out;
  }

  static void _incrementNonce(Uint8List nonce) {
    final view = ByteData.sublistView(nonce);
    view.setUint32(8, (view.getUint32(8) + 1) & 0xffffffff);
  }
}

class Sec2Exception implements Exception {
  const Sec2Exception(this.message, {this.status});
  final String message;

  /// protocomm-Status aus der Antwort (z. B. 6 = CryptoError).
  final int? status;

  @override
  String toString() => 'Sec2: $message';
}
