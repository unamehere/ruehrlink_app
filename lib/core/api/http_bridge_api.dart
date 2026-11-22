import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/json.dart';
import '../models/models.dart';
import 'bridge_api.dart';

/// Echte Brücke im Heim-WLAN: HTTP für Abfragen und Befehle, WebSocket für Live-Daten.
///
/// Im MVP unverschlüsselt (HTTP + Token) – TLS mit Zertifikats-Pinning folgt
/// nach dem MVP (siehe `ruehrlink_esp/docs/architektur.md`).
class HttpBridgeApi implements BridgeApi {
  HttpBridgeApi(this.target, {http.Client? client})
    : _client = client ?? http.Client();

  final NetworkTarget target;
  final http.Client _client;

  static const _timeout = Duration(seconds: 5);
  static const _reconnectDelay = Duration(seconds: 2);

  /// Herzschlag auf dem Live-Kanal: Ping so oft; kommt bis zum nächsten kein Pong, gilt die Box als weg
  /// (ausgesteckt sendet sie kein „Tschüss“ – ohne Ping merkt die App das sonst nie).
  static const _pingInterval = Duration(seconds: 3);

  late final StreamController<BridgeEvent> _events = StreamController.broadcast(
    onListen: _connect,
    onCancel: _disconnect,
  );
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSub;
  Timer? _reconnect;
  bool _closed = false;

  Uri _uri(String path, {String scheme = 'http', Map<String, String>? query}) =>
      Uri(
        scheme: scheme,
        host: target.host,
        port: target.port,
        path: '/api/v1/$path',
        queryParameters: scheme == 'ws' && target.token != null
            ? {'token': target.token}
            : query,
      );

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (target.token != null) 'Authorization': 'Bearer ${target.token}',
  };

  Future<http.Response> _send(String method, String path, [Object? body]) =>
      _request(method, path, json: body);

  /// [pass]: Statuscodes, die als Antwort zurückkommen statt als [BridgeException]
  /// (z. B. `412` beim Speichern eines Rezepts).
  Future<http.Response> _request(
    String method,
    String path, {
    Object? json,
    Uint8List? bytes,
    Map<String, String> headers = const {},
    Map<String, String>? query,
    Duration timeout = _timeout,
    Set<int> pass = const {},
  }) async {
    final request = http.Request(method, _uri(path, query: query))
      ..headers.addAll(_headers)
      ..headers.addAll(headers);
    if (json != null) request.body = jsonEncode(json);
    if (bytes != null) request.bodyBytes = bytes;
    try {
      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed)
          .timeout(timeout);
      if (pass.contains(response.statusCode)) return response;
      return switch (response.statusCode) {
        >= 200 && < 300 => response,
        401 || 403 => throw BridgeException(
          BridgeErrorKind.unauthorized,
          response.statusCode,
        ),
        >= 400 && < 500 => throw BridgeException(
          BridgeErrorKind.rejected,
          response.statusCode,
          _errorCode(response),
        ),
        _ => throw BridgeException(
          BridgeErrorKind.protocol,
          response.statusCode,
          _errorCode(response),
        ),
      };
    } on BridgeException {
      rethrow;
    } on Exception {
      // SocketException, TimeoutException, ClientException …
      throw const BridgeException(BridgeErrorKind.unreachable);
    }
  }

  static String? _errorCode(http.Response r) {
    try {
      final e = readMap(jsonDecode(utf8.decode(r.bodyBytes)))['error'];
      return e is String ? e : null;
    } on FormatException {
      return null;
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
  Future<SequenceState> startSequence(Program program) async =>
      SequenceState.fromJson(
        _decode(
          await _send('POST', 'sequence/start', {
            'name': program.name,
            'steps': [for (final s in program.steps) s.toJson()],
          }),
        ),
      );

  @override
  Future<void> abortSequence() => _send('POST', 'sequence/abort');

  @override
  Future<SequenceState> sequence() async =>
      SequenceState.fromJson(_decode(await _send('GET', 'sequence')));

  @override
  Future<List<Program>> programs() async => readList(
    _decode(await _send('GET', 'programs'))['programs'],
    Program.fromJson,
  );

  // --- Rezepte und Fotos ------------------------------------------------------

  /// Die ganze Bibliothek kann groß sein (die Brücke streamt sie).
  static const _longTimeout = Duration(seconds: 30);

  @override
  Future<RecipeChanges> recipeChanges(int since) async =>
      RecipeChanges.fromJson(
        _decode(
          await _request(
            'GET',
            'recipes',
            query: {'since': '$since'},
            timeout: _longTimeout,
          ),
        ),
      );

  @override
  Future<Recipe?> recipe(String id) async {
    final r = await _request('GET', 'recipes/$id', pass: const {404});
    if (r.statusCode == 404) return null;
    try {
      return Recipe.fromJson(_decode(r));
    } on TypeError {
      throw BridgeException(BridgeErrorKind.protocol, r.statusCode);
    }
  }

  @override
  Future<RecipeWriteResult> putRecipe(Recipe recipe) async => _writeResult(
    await _request(
      'PUT',
      'recipes/${recipe.id}',
      json: recipe.toJson(),
      headers: {'If-Match': '${recipe.rev}'},
      pass: const {412},
    ),
  );

  @override
  Future<RecipeWriteResult> deleteRecipe(String id, {required int rev}) async =>
      _writeResult(
        await _request(
          'DELETE',
          'recipes/$id',
          headers: {'If-Match': '$rev'},
          pass: const {412},
        ),
      );

  RecipeWriteResult _writeResult(http.Response r) {
    final j = _decode(r);
    if (r.statusCode == 412) {
      return RecipeConflict(
        currentRev: readInt(j['rev']),
        deleted: readBool(j['deleted']),
      );
    }
    return RecipeWritten(
      rev: readInt(j['rev']),
      updated: DateTime.tryParse(readString(j['updated'])),
    );
  }

  @override
  Future<Uint8List> media(String sha256) async =>
      (await _request('GET', 'media/$sha256', timeout: _longTimeout)).bodyBytes;

  @override
  Future<void> putMedia(String sha256, Uint8List webp) => _request(
    'PUT',
    'media/$sha256',
    bytes: webp,
    headers: {'Content-Type': 'image/webp'},
    timeout: _longTimeout,
  );

  @override
  Future<void> onboardMachine() => _send('POST', 'machine/onboard');

  @override
  Future<void> watchScale({int seconds = 30}) =>
      _send('POST', 'scale/watch', {'seconds': seconds});

  @override
  Future<double> tareScale() async =>
      readDouble(_decode(await _send('POST', 'scale/tare'))['tare']);

  @override
  Future<String> requestPairing(String deviceName) async {
    final response = await _send('POST', 'pair', {'name': deviceName});
    final id = _decode(response)['id'];
    if (id is! String || id.isEmpty) {
      throw BridgeException(BridgeErrorKind.protocol, response.statusCode);
    }
    return id;
  }

  @override
  Future<String?> pollPairing(String requestId) async {
    final response = await _send('POST', 'pair', {'id': requestId});
    if (response.statusCode == 202) return null;
    final token = _decode(response)['token'];
    if (token is! String || token.isEmpty) {
      throw BridgeException(BridgeErrorKind.protocol, response.statusCode);
    }
    return token;
  }

  @override
  Future<void> approvePairing(String requestId) =>
      _send('POST', 'pair/approve', {'id': requestId});

  @override
  Future<void> setTime(DateTime now) =>
      _send('POST', 'time', {'epoch': now.millisecondsSinceEpoch ~/ 1000});

  @override
  Future<void> reset() => _send('POST', 'reset');

  /// Eigener [HttpClient] statt `package:http`: nur so lässt sich der Fortschritt
  /// beim Senden zählen (flush wartet, bis der Block raus ist).
  @override
  Future<void> uploadFirmware(
    Uint8List image, {
    required String sha256,
    required String signature,
    void Function(double progress)? onProgress,
  }) async {
    const chunk = 16 * 1024;
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client.postUrl(_uri('ota'));
      req.headers
        ..contentType = ContentType.binary
        ..contentLength = image.length
        ..set('X-Sha256', sha256)
        ..set('X-Signature', signature);
      if (target.token != null) {
        req.headers.set('Authorization', 'Bearer ${target.token}');
      }
      for (var off = 0; off < image.length; off += chunk) {
        final end = min(off + chunk, image.length);
        req.add(Uint8List.sublistView(image, off, end));
        await req.flush().timeout(const Duration(seconds: 20));
        onProgress?.call(end / image.length);
      }
      // Prüfen (SHA-256, Signatur, Image) dauert auf der Brücke ein paar Sekunden.
      final res = await req.close().timeout(const Duration(seconds: 30));
      final body = await utf8.decodeStream(res);
      if (res.statusCode >= 200 && res.statusCode < 300) return;
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw BridgeException(BridgeErrorKind.unauthorized, res.statusCode);
      }
      String? code;
      try {
        final e = readMap(jsonDecode(body))['error'];
        code = e is String ? e : null;
      } on FormatException {
        code = null;
      }
      throw BridgeException(
        res.statusCode < 500
            ? BridgeErrorKind.rejected
            : BridgeErrorKind.protocol,
        res.statusCode,
        code,
      );
    } on BridgeException {
      rethrow;
    } on Exception {
      throw const BridgeException(BridgeErrorKind.unreachable);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Stream<BridgeEvent> events() => _events.stream;

  void _connect() {
    if (_closed || _channel != null) return;
    final channel = IOWebSocketChannel.connect(
      _uri('ws', scheme: 'ws'),
      pingInterval: _pingInterval,
      connectTimeout: _timeout,
    );
    _channel = channel;
    channel.ready.then(
      (_) {
        if (identical(_channel, channel)) {
          _setOnline(true);
        }
      },
      onError: (Object _) {}, // meldet der Stream selbst (onError)
    );
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

  bool? _online;

  void _setOnline(bool online) {
    if (_online == online || _events.isClosed) return;
    _online = online;
    _events.add(ConnectionEvent(online: online));
  }

  void _scheduleReconnect() {
    _dropChannel();
    _setOnline(false);
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

  @override
  void reconnect() {
    if (_closed || !_events.hasListener) return;
    _reconnect?.cancel();
    _dropChannel();
    _connect();
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
