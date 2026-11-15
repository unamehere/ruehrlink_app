// Security 2 (SRP6a + AES-GCM) für die Bluetooth-Einrichtung.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/core/provisioning/sec2/protobuf.dart';
import 'package:ruehrlink/core/provisioning/sec2/sec2_session.dart';
import 'package:ruehrlink/core/provisioning/sec2/srp6a.dart';
import 'package:pointycastle/export.dart';

BigInt _h(String hex) =>
    BigInt.parse(hex.replaceAll(RegExp(r'\s'), ''), radix: 16);
Uint8List _b(String hex) => bigIntToBytes(_h(hex));
Uint8List _hex(String hex) {
  final s = hex.replaceAll(RegExp(r'\s'), '');
  return Uint8List.fromList([
    for (var i = 0; i < s.length; i += 2)
      int.parse(s.substring(i, i + 2), radix: 16),
  ]);
}

Uint8List _sha512(List<List<int>> parts) {
  final d = SHA512Digest();
  for (final p in parts) {
    d.update(Uint8List.fromList(p), 0, p.length);
  }
  final out = Uint8List(64);
  d.doFinal(out, 0);
  return out;
}

void main() {
  test('SRP6a gegen RFC 5054 Anhang B (1024 Bit, SHA-1)', () {
    final srp = SrpClient(
      username: 'alice',
      password: 'password123',
      group: SrpGroup.rfc5054x1024,
      digest: SHA1Digest.new,
      privateKey: _h(
        '60975527 035CF2AD 1989806F 0407210B C81EDC04 E2762A56 AFD529DD DA2D4393',
      ),
    );
    final salt = _hex('BEB25379 D1A8581E B5A72767 3A2441EE');
    final b = _b('''
      BD0C6151 2C692C0C B6D041FA 01BB152D 4916A1E7 7AF46AE1 05393011
      BAF38964 DC46A067 0DD125B9 5A981652 236F99D9 B681CBF8 7837EC99
      6C6DA044 53728610 D0C6DDB5 8B318885 D7D82C7F 8DEB75CE 7BD4FBAA
      37089E6F 9C6059F3 88838E7A 00030B33 1EB76840 910440B1 B27AAEAE
      EB4012B7 D7665238 A8E3FB00 4B117B58''');
    expect(srp.k, _h('7556AA04 5AEF2CDD 07ABAF0F 665C3E81 8913186F'));
    expect(srp.x(salt), _h('94B7555A ABE9127C C58CCF49 93DB6CF8 4D16C124'));
    expect(
      srp.A,
      _h('''
      61D5E490 F6F1B795 47B0704C 436F523D D0E560F0 C64115BB 72557EC4
      4352E890 3211C046 92272D8B 2D1A5358 A2CF1B6E 0BFCF99F 921530EC
      8E393561 79EAE45E 42BA92AE ACED8251 71E1E8B9 AF6D9C03 E1327F44
      BE087EF0 6530E69F 66615261 EEF54073 CA11CF58 58F0EDFD FE15EFEA
      B349EF5D 76988A36 72FAC47B 0769447B'''),
    );
    expect(srp.u(b), _h('CE38B959 3487DA98 554ED47D 70A7AE5F 462EF019'));
    expect(
      srp.premasterSecret(salt, b),
      _h('''
      B0DC82BA BCF30674 AE450C02 87745E79 90A3381F 63B387AA F271A10D
      233861E3 59B48220 F7C4693C 9AE12B0A 6F67809F 0876E2D0 13800D6C
      41BB59B6 D5979B5C 00A172B4 A2A5903A 0BDCAF8A 709585EB 2AFAFA8F
      3499B200 210DCC1F 10EB3394 3CD67FC8 8A2F39A4 BE5BEC4E C0A3212D
      C346D7E4 74B29EDE 8A469FFE CA686E5A'''),
    );
  });

  test(
    'Handshake gegen eine nachgebaute Brücke (3072 Bit, SHA-512, esp_srp.c)',
    () {
      const user = 'ruehrlink', pop = 'abcde23456';
      final group = SrpGroup.rfc5054x3072;
      final n = group.n, g = group.g, len = group.byteLength;
      Uint8List pad(BigInt v) {
        final b = bigIntToBytes(v);
        return Uint8List(len)..setRange(len - b.length, len, b);
      }

      // Brücke: Salt + Verifier wie esp_srp_gen_salt_verifier.
      final salt = Uint8List.fromList(List.generate(16, (i) => i * 7 + 1));
      final x = bytesToBigInt(
        _sha512([
          salt,
          _sha512([utf8.encode('$user:$pop')]),
        ]),
      );
      final v = g.modPow(x, n);
      final k = bytesToBigInt(_sha512([pad(n), pad(g)]));
      final bPriv = _h('1234567890ABCDEF' * 4);
      final bPub = (k * v + g.modPow(bPriv, n)) % n;
      final bBytes = bigIntToBytes(bPub);

      final session = Sec2Session(username: user, pop: pop);
      // Cmd0 enthält Benutzer und A.
      final cmd0 = readProto(session.command0());
      expect(cmd0[2], 2);
      final sc0 = readProto(readProto(cmd0[12] as Uint8List)[20] as Uint8List);
      expect(utf8.decode(sc0[1] as Uint8List), user);
      final aBytes = sc0[2] as Uint8List;
      expect(aBytes.length, len);

      Uint8List resp(int msg, int field, Uint8List inner) =>
          (ProtoWriter()
                ..int32(2, 2)
                ..bytes(
                  12,
                  (ProtoWriter()
                        ..int32(1, msg)
                        ..bytes(field, inner))
                      .toBytes(),
                ))
              .toBytes();
      session.response0(
        resp(
          1,
          21,
          (ProtoWriter()
                ..bytes(2, bBytes)
                ..bytes(3, salt))
              .toBytes(),
        ),
      );

      // Brücke rechnet S, K, M und H_AMK nach esp_srp.c.
      final a = bytesToBigInt(aBytes);
      final u = bytesToBigInt(_sha512([pad(a), pad(bPub)]));
      final s = (a * v.modPow(u, n)).modPow(bPriv, n);
      final key = _sha512([bigIntToBytes(s)]);
      final hN = _sha512([pad(n)]), hG = _sha512([pad(g)]);
      final m = _sha512([
        [for (var i = 0; i < 64; i++) hN[i] ^ hG[i]],
        _sha512([utf8.encode(user)]),
        salt,
        aBytes,
        bBytes,
        key,
      ]);
      final sc1 = readProto(
        readProto(readProto(session.command1())[12] as Uint8List)[22]
            as Uint8List,
      );
      expect(sc1[1], m, reason: 'Client-Beweis M');
      final hamk = _sha512([aBytes, m, key]);
      final nonce = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 0, 0, 0, 1]);
      session.response1(
        resp(
          3,
          23,
          (ProtoWriter()
                ..bytes(2, hamk)
                ..bytes(3, nonce))
              .toBytes(),
        ),
      );
      expect(session.established, isTrue);

      // Brücke entschlüsselt mit Nonce …01 und antwortet mit …02.
      final bridge = Sec2Session.established(key.sublist(0, 32), nonce);
      final request = session.encrypt(Uint8List.fromList(utf8.encode('{}')));
      expect(utf8.decode(bridge.decrypt(request)), '{}');
      final answer = bridge.encrypt(
        Uint8List.fromList(utf8.encode('{"ok":true}')),
      );
      expect(utf8.decode(session.decrypt(answer)), '{"ok":true}');
    },
  );

  test('AES-256-GCM-Rahmen: NIST-Testfall 14, Zähler im Nonce', () {
    final session = Sec2Session.established(Uint8List(32), Uint8List(12));
    final out = session.encrypt(Uint8List(16));
    // Chiffretext + 16 Byte Tag.
    expect(
      out,
      _hex(
        'cea7403d4d606b6e074ec5d3baf39d18'
        'd0d1c8a799996bf0265b98b5d48ab919',
      ),
    );
    // Danach Nonce …01: gleiche Eingabe, anderes Ergebnis.
    expect(session.encrypt(Uint8List(16)), isNot(out));
    // Manipulierter Rahmen wird abgelehnt.
    final bad = Sec2Session.established(Uint8List(32), Uint8List(12));
    expect(
      () => bad.decrypt(Uint8List.fromList(out)..[0] ^= 1),
      throwsA(isA<Sec2Exception>()),
    );
  });
}
