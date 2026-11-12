import 'json.dart';

/// Mit welcher Brücke spricht die App? Wird lokal gespeichert.
sealed class BridgeTarget {
  const BridgeTarget();

  factory BridgeTarget.fromJson(Json json) => json['kind'] == 'network'
      ? NetworkTarget(
          host: readString(json['host']),
          port: readInt(json['port'], 80),
          token: json['token'] as String?,
          id: json['id'] as String?,
          name: json['name'] as String?,
        )
      : const DemoTarget();

  Json toJson();
}

/// Demo-Modus: simulierte Brücke im Handy, für Entwicklung und Vorführung.
class DemoTarget extends BridgeTarget {
  const DemoTarget();

  @override
  Json toJson() => {'kind': 'demo'};
}

/// Echte Brücke im Heim-WLAN.
class NetworkTarget extends BridgeTarget {
  const NetworkTarget({
    required this.host,
    this.port = 80,
    this.token,
    this.id,
    this.name,
  });

  final String host;
  final int port;

  /// Zugangs-Token aus Bluetooth-Einrichtung oder bestätigter
  /// Kopplungsanfrage (`POST /api/v1/pair`).
  final String? token;
  final String? id;
  final String? name;

  NetworkTarget withToken(String token) =>
      NetworkTarget(host: host, port: port, token: token, id: id, name: name);

  @override
  Json toJson() => {
    'kind': 'network',
    'host': host,
    'port': port,
    if (token != null) 'token': token,
    if (id != null) 'id': id,
    if (name != null) 'name': name,
  };
}
