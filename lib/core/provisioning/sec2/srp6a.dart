import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

/// SRP-6a-Client, bytegenau wie `esp_srp.c` aus ESP-IDF (protocomm Security 2):
///
/// - Gruppe RFC 5054 3072 Bit, g = 5, Hash SHA-512
/// - x = H(salt | H(I ":" P))
/// - k = H(N | PAD(g)), u = H(PAD(A) | PAD(B))
/// - S = (B − k·v)^(a + u·x) mod N, K = H(S) (S ohne führende Nullbytes)
/// - M = H(H(N) xor H(PAD(g)) | H(I) | salt | A | B | K), H_AMK = H(A | M | K)
///
/// Gruppe und Hash sind austauschbar, damit sich die Rechnung gegen die
/// Testvektoren aus RFC 5054 Anhang B (1024 Bit, SHA-1) prüfen lässt.
class SrpClient {
  SrpClient({
    required this.username,
    required this.password,
    SrpGroup? group,
    Digest Function()? digest,
    @visibleForTesting BigInt? privateKey,
  }) : group = group ?? SrpGroup.rfc5054x3072,
       _digest = digest ?? SHA512Digest.new {
    a = privateKey ?? _randomPrivateKey();
    A = this.group.g.modPow(a, this.group.n);
  }

  final String username;
  final String password;
  final SrpGroup group;
  final Digest Function() _digest;

  late final BigInt a;

  /// Öffentlicher Schlüssel des Clients.
  // ignore: non_constant_identifier_names
  late final BigInt A;

  Uint8List? _hamk;
  Uint8List? _key;
  bool _verified = false;

  /// A in voller Gruppenlänge – so wird es gesendet und in M/H_AMK verwendet.
  Uint8List get publicKey => _pad(A, group.byteLength);

  /// Sitzungsschlüssel K (64 Byte bei SHA-512), erst nach [verifyServerProof].
  Uint8List get sessionKey {
    if (!_verified || _key == null) throw StateError('SRP: nicht bestätigt');
    return _key!;
  }

  static BigInt _randomPrivateKey() {
    final r = Random.secure();
    final bytes = Uint8List.fromList(List.generate(32, (_) => r.nextInt(256)));
    bytes[0] |= 0x80; // volle 256 Bit
    return bytesToBigInt(bytes);
  }

  Uint8List _hash(List<List<int>> parts) {
    final d = _digest();
    for (final p in parts) {
      d.update(Uint8List.fromList(p), 0, p.length);
    }
    final out = Uint8List(d.digestSize);
    d.doFinal(out, 0);
    return out;
  }

  @visibleForTesting
  BigInt get k => bytesToBigInt(
    _hash([_pad(group.n, group.byteLength), _pad(group.g, group.byteLength)]),
  );

  @visibleForTesting
  BigInt x(Uint8List salt) => bytesToBigInt(
    _hash([
      salt,
      _hash([utf8.encode(username), utf8.encode(':'), utf8.encode(password)]),
    ]),
  );

  @visibleForTesting
  BigInt u(Uint8List bBytes) => bytesToBigInt(
    _hash([publicKey, _pad(bytesToBigInt(bBytes), group.byteLength)]),
  );

  @visibleForTesting
  BigInt premasterSecret(Uint8List salt, Uint8List bBytes) {
    final n = group.n;
    final b = bytesToBigInt(bBytes);
    final xv = x(salt);
    final v = group.g.modPow(xv, n);
    final base = (b - k * v) % n;
    return base.modPow(a + u(bBytes) * xv, n);
  }

  /// Antwort auf die Herausforderung der Brücke (Salt, B) → Client-Beweis M.
  Uint8List processChallenge(Uint8List salt, Uint8List bBytes) {
    final b = bytesToBigInt(bBytes);
    if (b % group.n == BigInt.zero) {
      throw const FormatException('SRP: ungültiger Server-Schlüssel');
    }
    if (u(bBytes) == BigInt.zero) throw const FormatException('SRP: u = 0');
    final key = _hash([bigIntToBytes(premasterSecret(salt, bBytes))]);
    final hN = _hash([_pad(group.n, group.byteLength)]);
    final hG = _hash([_pad(group.g, group.byteLength)]);
    final nXorG = Uint8List(hN.length);
    for (var i = 0; i < hN.length; i++) {
      nXorG[i] = hN[i] ^ hG[i];
    }
    final m = _hash([
      nXorG,
      _hash([utf8.encode(username)]),
      salt,
      publicKey,
      bBytes,
      key,
    ]);
    _key = key;
    _hamk = _hash([publicKey, m, key]);
    return m;
  }

  /// Beweis der Brücke prüfen. Erst danach ist [sessionKey] gültig.
  bool verifyServerProof(Uint8List hamk) {
    final expected = _hamk;
    if (expected == null || hamk.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < hamk.length; i++) {
      diff |= hamk[i] ^ expected[i];
    }
    return _verified = diff == 0;
  }
}

class SrpGroup {
  const SrpGroup._(this._nHex, this._g);

  final String _nHex;
  final int _g;

  BigInt get n => BigInt.parse(_nHex, radix: 16);
  BigInt get g => BigInt.from(_g);
  int get byteLength => (_nHex.length + 1) ~/ 2;

  /// RFC 5054 Anhang A, 1024 Bit (nur für die Testvektoren).
  static const rfc5054x1024 = SrpGroup._(
    'EEAF0AB9ADB38DD69C33F80AFA8FC5E86072618775FF3C0B9EA2314C9C256576D674DF74'
    '96EA81D3383B4813D692C6E0E0D5D8E250B98BE48E495C1D6089DAD15DC7D7B46154D6B6'
    'CE8EF4AD69B15D4982559B297BCF1885C529F566660E57EC68EDBC3C05726CC02FD4CBF4'
    '976EAA9AFD5138FE8376435B9FC61D2FC0EB06E3',
    2,
  );

  /// RFC 5054 Anhang A, 3072 Bit, g = 5 – die Gruppe von ESP-IDF Security 2.
  static const rfc5054x3072 = SrpGroup._(
    'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA6'
    '3B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245'
    'E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F2411'
    '7C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F'
    '83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08'
    'CA18217C32905E462E36CE3BE39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9'
    'DE2BCBF6955817183995497CEA956AE515D2261898FA051015728E5A8AAAC42DAD33170D'
    '04507A33A85521ABDF1CBA64ECFB850458DBEF0A8AEA71575D060C7DB3970F85A6E1E4C7'
    'ABF5AE8CDB0933D71E8C94E04A25619DCEE3D2261AD2EE6BF12FFA06D98A0864D8760273'
    '3EC86A64521F2B18177B200CBBE117577A615D6C770988C0BAD946E208E24FA074E5AB31'
    '43DB5BFCE0FD108E4B82D120A93AD2CAFFFFFFFFFFFFFFFF',
    5,
  );
}

/// Big-Endian ohne Vorzeichen.
BigInt bytesToBigInt(List<int> bytes) {
  var r = BigInt.zero;
  for (final b in bytes) {
    r = (r << 8) | BigInt.from(b);
  }
  return r;
}

/// Big-Endian ohne führende Nullbytes (wie `esp_mpi_to_bin`).
Uint8List bigIntToBytes(BigInt v) {
  if (v == BigInt.zero) return Uint8List(1);
  final hex = v.toRadixString(16);
  final s = hex.length.isOdd ? '0$hex' : hex;
  return Uint8List.fromList([
    for (var i = 0; i < s.length; i += 2)
      int.parse(s.substring(i, i + 2), radix: 16),
  ]);
}

Uint8List _pad(BigInt v, int length) {
  final b = bigIntToBytes(v);
  if (b.length >= length) return b;
  return Uint8List(length)..setRange(length - b.length, length, b);
}
