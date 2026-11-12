// Kleine Helfer zum Lesen von JSON. Die Brücke liefert Zahlen manchmal als
// Ganzzahl, manchmal als Kommazahl – wir lesen tolerant und schreiben exakt.

typedef Json = Map<String, dynamic>;

int readInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

int? readIntOrNull(Object? v) => v is num ? v.toInt() : null;

double readDouble(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : fallback;

bool readBool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

String readString(Object? v, [String fallback = '']) =>
    v is String ? v : fallback;

Json readMap(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};

List<T> readList<T>(Object? v, T Function(Json) parse) => v is List
    ? v.whereType<Map>().map((e) => parse(e.cast<String, dynamic>())).toList()
    : const [];
