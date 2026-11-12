import 'dart:async';

import '../models/models.dart';
import 'bridge_api.dart';

/// Simulierte Brücke samt Gerät – für Entwicklung ohne Hardware und den Demo-Modus.
///
/// Verhält sich wie die echte Brücke: bestätigt Werte per [AckEvent], prüft die
/// Grenzen aus [caps], „dreht“ nach kurzer Zeit selbst am Knopf (weil kein Fernstart),
/// zählt die Restzeit herunter und heizt die Schüssel langsam auf.
class FakeBridgeApi implements BridgeApi {
  FakeBridgeApi({
    this.caps = demoCaps,
    this.latency = const Duration(milliseconds: 250),
    this.knobDelay = const Duration(seconds: 3),
    this._paired = true,
  }) {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Ein erfundenes Gerät mit typischen Grenzen.
  static const demoCaps = ApplianceCaps(
    model: 'demo',
    name: 'Demo-Küchenmaschine',
    tempMin: 20,
    tempMax: 180,
    speedMax: 10,
    timeMaxS: 8 * 60 * 60,
    hasScale: true,
    remoteStart: false,
  );

  static const _roomTemperature = 22;

  final ApplianceCaps caps;
  final Duration latency;

  /// So lange „braucht“ die Nutzerin, bis sie nach dem Senden am Knopf dreht.
  final Duration knobDelay;

  final _events = StreamController<BridgeEvent>.broadcast();
  late final Timer _ticker;
  Timer? _knob;
  Timer? _onboard;
  bool _paired;
  MachineSettings? _set;
  double _bowl = _roomTemperature.toDouble();
  late ApplianceStatus _status = ApplianceStatus(
    bowlTemperature: _roomTemperature,
    speedSetting: 0,
    remainingTime: 0,
    motorOn: false,
    bowlFitted: true,
    headLiftInterlockClosed: true,
    connected: _paired,
  );

  Future<void> _wait() => Future.delayed(latency);

  @override
  Future<BridgeInfo> info() async {
    await _wait();
    return BridgeInfo(
      id: 'DEMO',
      name: 'Freikoch Brücke (Demo)',
      fw: '0.1.0',
      api: 1,
      storage: const StorageInfo(
        backend: 'sd',
        totalKB: 30000000,
        freeKB: 29000000,
      ),
      appliance: ApplianceInfo(
        paired: _paired,
        connected: _status.connected,
        caps: _paired ? caps : null,
      ),
    );
  }

  @override
  Future<ApplianceStatus> state() async {
    await _wait();
    return _status;
  }

  @override
  Future<void> sendProgram(MachineSettings settings) async {
    await _wait();
    if (!_status.connected) {
      throw const BridgeException(BridgeErrorKind.rejected, 409);
    }
    if (caps.clamp(settings) != settings) {
      throw const BridgeException(BridgeErrorKind.rejected, 400);
    }
    _set = settings;
    _update(
      _status.copyWith(
        speedSetting: settings.speed,
        remainingTime: settings.time,
      ),
    );
    _emit(const AckEvent(cmd: AckEvent.setProgramme, ok: true));

    // Läuft schon? Dann übernimmt die Maschine die Werte sofort (wie die echte).
    if (!_status.motorOn && settings.time > 0) {
      _knob?.cancel();
      _knob = Timer(knobDelay, () {
        if (_set != null && _status.remainingTime > 0) {
          _update(_status.copyWith(motorOn: true));
        }
      });
    }
  }

  @override
  Future<void> stop() async {
    await _wait();
    _knob?.cancel();
    if (_status.motorOn) {
      // Wie bei der echten Brücke: Stopp = Restzeit auf 1 s.
      _update(_status.copyWith(remainingTime: 1));
    } else {
      _set = null;
      _update(_status.copyWith(remainingTime: 0, speedSetting: 0));
    }
  }

  @override
  Future<void> onboardMachine() async {
    await _wait();
    _onboard?.cancel();
    _onboard = Timer(const Duration(seconds: 2), () {
      _paired = true;
      _update(_status.copyWith(connected: true));
    });
  }

  @override
  Future<String?> pair() async {
    await _wait();
    return 'demo-token';
  }

  @override
  Stream<BridgeEvent> events() => _events.stream;

  void _tick() {
    var s = _status;
    final target = s.motorOn ? (_set?.temperature ?? 0) : 0;
    // Aufheizen ca. 2 °C/s, Abkühlen langsamer, nie unter Raumtemperatur.
    if (target > _bowl) {
      _bowl = (_bowl + 2).clamp(0, target.toDouble());
    } else if (_bowl > _roomTemperature) {
      _bowl = (_bowl - 0.5).clamp(_roomTemperature.toDouble(), 999);
    }
    s = s.copyWith(bowlTemperature: _bowl.round());

    if (s.motorOn) {
      final rest = s.remainingTime - 1;
      s = rest > 0
          ? s.copyWith(remainingTime: rest)
          : s.copyWith(remainingTime: 0, motorOn: false, speedSetting: 0);
      if (rest <= 0) _set = null;
    }
    _update(s);
  }

  void _update(ApplianceStatus s) {
    _status = s;
    _emit(StatusEvent(s));
  }

  void _emit(BridgeEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  @override
  void close() {
    _ticker.cancel();
    _knob?.cancel();
    _onboard?.cancel();
    unawaited(_events.close());
  }
}
