import 'dart:typed_data';

/// Minimaler Protobuf-Kodierer/-Leser – genau so viel, wie die protocomm-
/// Nachrichten (session.proto / sec2.proto aus ESP-IDF) brauchen:
/// Varints und längenpräfixierte Felder. Statt eines Codegenerators.
class ProtoWriter {
  final _out = BytesBuilder(copy: false);

  void _varint(int v) {
    var x = v;
    while (x >= 0x80) {
      _out.addByte((x & 0x7f) | 0x80);
      x >>= 7;
    }
    _out.addByte(x);
  }

  /// Varint-Feld; 0 wird wie in proto3 weggelassen.
  void int32(int field, int value) {
    if (value == 0) return;
    _varint(field << 3);
    _varint(value);
  }

  /// Längenpräfixiertes Feld (bytes oder eingebettete Nachricht).
  void bytes(int field, List<int> value) {
    _varint((field << 3) | 2);
    _varint(value.length);
    _out.add(value);
  }

  Uint8List toBytes() => _out.toBytes();
}

/// Liest eine Nachricht in eine Feldnummer → Wert-Tabelle (letzter Wert gewinnt).
/// Varints werden zu `int`, längenpräfixierte Felder zu `Uint8List`.
Map<int, Object> readProto(Uint8List data) {
  final fields = <int, Object>{};
  var i = 0;
  int varint() {
    var result = 0, shift = 0;
    while (true) {
      if (i >= data.length) throw const FormatException('Protobuf: zu kurz');
      final b = data[i++];
      result |= (b & 0x7f) << shift;
      if (b < 0x80) return result;
      shift += 7;
      if (shift > 63) throw const FormatException('Protobuf: Varint zu lang');
    }
  }

  while (i < data.length) {
    final key = varint();
    final field = key >> 3;
    switch (key & 7) {
      case 0:
        fields[field] = varint();
      case 2:
        final len = varint();
        if (i + len > data.length) {
          throw const FormatException('Protobuf: Feld zu lang');
        }
        fields[field] = Uint8List.sublistView(data, i, i + len);
        i += len;
      case 1:
        i += 8; // fixed64 – kommt hier nicht vor, überspringen
      case 5:
        i += 4; // fixed32
      default:
        throw FormatException('Protobuf: unbekannter Typ ${key & 7}');
    }
  }
  return fields;
}
