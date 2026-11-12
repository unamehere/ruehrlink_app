import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/json.dart';
import '../models/models.dart';
import 'bridge_api.dart';

/// Echte Brücke im Heim-WLAN: HTTP für Abfragen und Befehle, WebSocket für Live-Daten.
///
/// Im MVP unverschlüsselt (HTTP + Token) – TLS mit Zertifikats-Pinning folgt
/// nach dem MVP (siehe `freikoch_esp/docs/architektur.md`).
class HttpBridgeApi implements BridgeApi {
  HttpBridgeApi(this.target, {http.Client? client})
    : _client = client ?? http.Client();

  final NetworkTarget target;
  final http.Client _client;

  static const _timeout = Duration(seconds: 5);
  static const _reconnectDelay = Duration(seconds: 2);

  late final StreamController<BridgeEvent> _events = StreamController.broadcast(
    onListen: _connect,
    onCancel: _disconnect,
  );
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSub;
  Timer? _reconnect;
  bool _closed = false;

  Uri _uri(String path, {String scheme = 'http'}) => Uri(
    scheme: scheme,
    host: target.host,
    port: target.port,
    path: '/api/v1/$path',
    queryParameters: scheme == 'ws' && target.token != null
        ? {'token': target.token}
        : null,
  );

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (target.token != null) 'Authorization': 'Bearer ${target.token}',
  };

  Future<http.Response> _send(
    String method,
    String path, [
    Object? body,
  ]) async {
    final request = http.Request(method, _uri(path))..headers.addAll(_headers);
    if (body != null) request.body = jsonEncode(body);
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      return switch (response.statusCode) {
        >= 200 && < 300 => response,
        401 || 403 => throw BridgeException(
          BridgeErrorKind.unauthorized,
          response.statusCode,
        ),
        >= 400 && < 500 => throw BridgeException(
          BridgeErrorKind.rejected,
          response.statusCode,
        ),
        _ => throw BridgeException(
          BridgeErrorKind.protocol,
          response.statusCode,
        ),
      };
    } on BridgeException {
      rethrow;
    } on Exception {
      // SocketException, TimeoutException, ClientException …
      throw const BridgeException(BridgeErrorKind.unreachable);
    }
  }

  Json _decode(http.Response r) {
    try {
      return readMap(jsonDecode(utf8.decode(r.bodyBytes)));
    } on FormatException {
      throw BridgeException(BridgeErrorKind.protocol, r.statusCode);
    }
  }

  @override
  Future<BridgeInfo> info() async =>
      BridgeInfo.fromJson(_decode(await _send('GET', 'info')));

  @override
  Future<ApplianceStatus> state() async =>
      ApplianceStatus.fromJson(_decode(await _send('GET', 'state')));

  @override
  Future<void> sendProgram(MachineSettings settings) =>
      _send('POST', 'machine/program', settings.toJson());

  @override
  Future<void> stop() => _send('POST', 'machine/stop');

  @override
  Future<void> onboardMachine() => _send('POST', 'machine/onboard');

  @override
  Future<String?> pair() async {
    final response = await _send('POST', 'pair');
    if (response.statusCode == 202) return null;
    final token = _decode(response)['token'];
    if (token is! String || token.isEmpty) {
      throw BridgeException(BridgeErrorKind.protocol, response.statusCode);
    }
    return token;
  }

  @override
  Stream<BridgeEvent> events() => _events.stream;

  void _connect() {
    if (_closed || _channel != null) return;
    final channel = WebSocketChannel.connect(_uri('ws', scheme: 'ws'));
    _channel = channel;
    _wsSub = channel.stream.listen(
      (message) {
        if (message is! String) return;
        try {
          _events.add(BridgeEvent.fromJson(readMap(jsonDecode(message))));
        } on FormatException {
          // Kaputte Nachricht ignorieren – die nächste kommt bestimmt.
        }
      },
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
    );
  }

  void _scheduleReconnect() {
    _dropChannel();
    if (_closed || !_events.hasListener) return;
    _reconnect?.cancel();
    _reconnect = Timer(_reconnectDelay, _connect);
  }

  void _dropChannel() {
    unawaited(_wsSub?.cancel());
    unawaited(_channel?.sink.close());
    _wsSub = null;
    _channel = null;
  }

  void _disconnect() {
    _reconnect?.cancel();
    _dropChannel();
  }

  @override
  void close() {
    _closed = true;
    _disconnect();
    unawaited(_events.close());
    _client.close();
  }
}
