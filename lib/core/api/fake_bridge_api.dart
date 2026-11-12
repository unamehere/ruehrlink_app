import 'dart:async';

import '../models/models.dart';
import 'bridge_api.dart';

/// Simulierte Brücke samt Gerät – für Entwicklung ohne Hardware und den Demo-Modus.
///
/// Verhält sich wie die echte Brücke: bestätigt Werte per [AckEvent], prüft die
/// Grenzen aus [caps], „drückt“ nach kurzer Zeit selbst den Startknopf (weil kein
/// Fernstart), zählt die Restzeit herunter und heizt die Schüssel langsam auf.
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
    speeds: demoSpeeds,
    timeMaxS: 8 * 60 * 60,
    hasScale: true,
    remoteStart: false,
  );

  /// Stufen des Demo-Geräts – gleiche Werte wie die echte Brücke liefert.
  static const demoSpeeds = [
    // Reihenfolge wie am Drehknopf: links herum Intervall-Rühren und Puls,
    // in der Mitte „Aus“, rechts herum die Dauerstufen min … max.
    // Wie die echte KCL95 (gemessen 12.11.2026); P ist per Fernsteuerung nicht verfügbar.
    SpeedOption(v: 3, label: '4', group: SpeedGroup.stir),
    SpeedOption(v: 2, label: '3', group: SpeedGroup.stir),
    SpeedOption(v: 1, label: '2', group: SpeedGroup.stir),
    SpeedOption(v: 4, label: '1', group: SpeedGroup.stir),
    SpeedOption(v: 0, label: 'Aus', group: SpeedGroup.off),
    SpeedOption(v: 5, label: 'min', group: SpeedGroup.continuous),
    SpeedOption(v: 6, label: '1', group: SpeedGroup.continuous),
    SpeedOption(v: 7, label: '2', group: SpeedGroup.continuous),
    SpeedOption(v: 8, label: '3', group: SpeedGroup.continuous),
    SpeedOption(v: 9, label: '4', group: SpeedGroup.continuous),
    SpeedOption(v: 10, label: '5', group: SpeedGroup.continuous),
    SpeedOption(v: 11, label: '6', group: SpeedGroup.continuous),
    SpeedOption(v: 12, label: 'max', group: SpeedGroup.continuous),
  ];

  static const _roomTemperature = 22;

  /// Ab dieser Schüsseltemperatur meldet die Demo „heiß“.
  static const _hotFrom = 60;

  final ApplianceCaps caps;
  final Duration latency;

  /// So lange „braucht“ die Nutzerin, bis sie nach dem Senden den Startknopf drückt.
  final Duration knobDelay;

  final _events = StreamController<BridgeEvent>.broadcast();
  late final Timer _ticker;
  Timer? _knob;
  Timer? _onboard;
  bool _paired;
  MachineSettings? _set;
  double _bowl = _roomTemperature.toDouble();
  late ApplianceStatus _status = ApplianceStatus.disconnected.copyWith(
    connected: _paired,
    bowlFitted: true,
    lidClosed: true,
    bowlTemp: _roomTemperature,
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
        speedSet: settings.speed,
        tempSet: settings.temperature,
        remainingS: settings.time,
      ),
    );
    _emit(const AckEvent(cmd: AckEvent.setProgramme, ok: true));

    // Läuft schon? Dann übernimmt die Maschine die Werte sofort (wie die echte).
    if (!_status.running && settings.time > 0) {
      _knob?.cancel();
      _knob = Timer(knobDelay, () {
        if (_set != null && _status.remainingS > 0) {
          _update(_status.copyWith(running: true));
        }
      });
    }
  }

  @override
  Future<void> stop() async {
    await _wait();
    _knob?.cancel();
    if (_status.running) {
      // Wie bei der echten Brücke: Stopp = Restzeit auf 1 s.
      _update(_status.copyWith(remainingS: 1));
    } else {
      _set = null;
      _update(_status.copyWith(remainingS: 0, speedSet: 0, tempSet: 0));
    }
  }

  /// Kopplung wie bei der echten Brücke: Gerät kurz weg, „sucht“, „gesendet“, verbunden.
  @override
  Future<void> onboardMachine() async {
    await _wait();
    _onboard?.cancel();
    _update(_status.copyWith(connected: false));
    _emit(const OnboardEvent(OnboardState.searching));
    var step = 0;
    _onboard = Timer.periodic(const Duration(seconds: 1), (t) {
      step++;
      if (step == 1) {
        _emit(const OnboardEvent(OnboardState.sent));
      } else {
        t.cancel();
        _paired = true;
        _update(_status.copyWith(connected: true));
        _emit(const OnboardEvent(OnboardState.done));
      }
    });
  }

  Timer? _pairTimer;
  bool? _pairApproved; // null = keine Anfrage

  /// Demo: Die Anfrage gilt nach 3 s als von einem anderen Handy bestätigt.
  @override
  Future<String> requestPairing(String deviceName) async {
    await _wait();
    _pairApproved = false;
    _pairTimer?.cancel();
    _pairTimer = Timer(const Duration(seconds: 3), () => _pairApproved = true);
    return 'demo-anfrage';
  }

  @override
  Future<String?> pollPairing(String requestId) async {
    await _wait();
    return switch (_pairApproved) {
      null => throw const BridgeException(BridgeErrorKind.rejected, 404),
      true => 'demo-token',
      false => null,
    };
  }

  @override
  Future<void> approvePairing(String requestId) => _wait();

  @override
  Stream<BridgeEvent> events() => _events.stream;

  void _tick() {
    var s = _status;
    final target = s.running ? (_set?.temperature ?? 0) : 0;
    // Aufheizen ca. 2 °C/s, Abkühlen langsamer, nie unter Raumtemperatur.
    if (target > _bowl) {
      _bowl = (_bowl + 2).clamp(0, target.toDouble());
    } else if (_bowl > _roomTemperature) {
      _bowl = (_bowl - 0.5).clamp(_roomTemperature.toDouble(), 999);
    }
    s = s.copyWith(
      bowlTemp: _bowl.round(),
      heating: target > _bowl.round(),
      hot: _bowl >= _hotFrom,
    );

    if (s.running) {
      final rest = s.remainingS - 1;
      s = rest > 0
          ? s.copyWith(remainingS: rest)
          : s.copyWith(
              remainingS: 0,
              running: false,
              heating: false,
              speedSet: 0,
              tempSet: 0,
            );
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
    _pairTimer?.cancel();
    unawaited(_events.close());
  }
}
