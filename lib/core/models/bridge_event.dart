import 'appliance_status.dart';
import 'json.dart';

/// Nachricht der Brücke über den WebSocket `/api/v1/ws`: `{"t": typ, "d": daten}`.
sealed class BridgeEvent {
  const BridgeEvent();

  factory BridgeEvent.fromJson(Json json) {
    final d = readMap(json['d']);
    return switch (json['t']) {
      'status' => StatusEvent(ApplianceStatus.fromJson(d)),
      'weight' => WeightEvent(readDouble(d['g'])),
      'seq' => SequenceEvent(SequenceState.fromJson(d)),
      'ack' => AckEvent(cmd: readString(d['cmd']), ok: readBool(d['ok'])),
      'recipes' => RecipesChangedEvent(readInt(d['rev'])),
      'pairRequest' => PairRequestEvent(
        id: readString(d['id']),
        name: readString(d['name']),
      ),
      'onboard' => OnboardEvent(switch (d['state']) {
        'searching' => OnboardState.searching,
        'sent' => OnboardState.sent,
        'done' => OnboardState.done,
        'failed' => OnboardState.failed,
        _ => OnboardState.unknown,
      }, reason: d['reason'] as String?),
      final t => UnknownEvent(t is String ? t : '?'),
    };
  }
}

class StatusEvent extends BridgeEvent {
  const StatusEvent(this.status);
  final ApplianceStatus status;
}

/// Gewicht auf der Waage in Gramm (max. 10 Nachrichten/s).
class WeightEvent extends BridgeEvent {
  const WeightEvent(this.grams);
  final double grams;
}

class SequenceEvent extends BridgeEvent {
  const SequenceEvent(this.state);
  final SequenceState state;
}

/// Bestätigung der Maschine für einen Befehl, z. B. `setProgramme`.
class AckEvent extends BridgeEvent {
  const AckEvent({required this.cmd, required this.ok});

  /// Befehlsname für gesendete Einzelwerte.
  static const setProgramme = 'setProgramme';

  final String cmd;
  final bool ok;
}

/// Die Rezeptbibliothek hat sich geändert → `GET /recipes?since=` holen.
class RecipesChangedEvent extends BridgeEvent {
  const RecipesChangedEvent(this.rev);
  final int rev;
}

/// Ein neues Gerät möchte sich koppeln – eine schon gekoppelte App fragt nach
/// und bestätigt mit `POST /api/v1/pair/approve`.
class PairRequestEvent extends BridgeEvent {
  const PairRequestEvent({required this.id, required this.name});
  final String id;
  final String name;
}

enum OnboardState { searching, sent, done, failed, unknown }

/// Fortschritt der Maschinen-Kopplung (`POST /api/v1/machine/onboard`).
class OnboardEvent extends BridgeEvent {
  const OnboardEvent(this.state, {this.reason});
  final OnboardState state;
  final String? reason;
}

/// Unbekannter Typ – neuere Brücke. Wird ignoriert, nicht als Fehler behandelt.
class UnknownEvent extends BridgeEvent {
  const UnknownEvent(this.type);
  final String type;
}

enum SequenceRunState {
  idle,

  /// Werte sind gesendet – jetzt den Knopf an der Maschine drücken.
  waitingStart,
  running,
  paused,
  done,
  aborted,
  unknown,
}

/// Fortschritt eines Programms auf der Brücke (intern „sequence“), siehe
/// `GET /api/v1/sequence` und WS `seq` in `ruehrlink_esp/docs/api.md`.
class SequenceState {
  const SequenceState({
    this.programId,
    this.name = '',
    required this.step,
    required this.of,
    this.label = '',
    required this.state,
    this.reason,
    this.stepRemainingS = 0,
  });

  static const idle = SequenceState(
    step: 0,
    of: 0,
    state: SequenceRunState.idle,
  );

  /// `null` bei Programmen, die die App direkt mitgeschickt hat.
  final String? programId;
  final String name;

  /// Aktueller Schritt ab 1, `0` = kein Programm.
  final int step;
  final int of;
  final String label;
  final SequenceRunState state;

  /// Warum gewartet, pausiert oder abgebrochen wurde, z. B. `press_start`,
  /// `lid_open`, `bowl_missing`, `machine_paused`, `disconnected`, `no_ack`,
  /// `user`, `timeout`.
  final String? reason;
  final int stepRemainingS;

  /// Läuft gerade ein Programm (wartend, laufend oder pausiert)?
  bool get active =>
      state == SequenceRunState.waitingStart ||
      state == SequenceRunState.running ||
      state == SequenceRunState.paused;

  factory SequenceState.fromJson(Json json) => SequenceState(
    programId: json['programId'] is String ? json['programId'] as String : null,
    name: readString(json['name']),
    step: readInt(json['step']),
    of: readInt(json['of']),
    label: readString(json['label']),
    state: switch (json['state']) {
      'idle' => SequenceRunState.idle,
      'running' => SequenceRunState.running,
      'waiting_start' => SequenceRunState.waitingStart,
      'paused' => SequenceRunState.paused,
      'done' => SequenceRunState.done,
      'aborted' => SequenceRunState.aborted,
      _ => SequenceRunState.unknown,
    },
    reason: json['reason'] is String ? json['reason'] as String : null,
    stepRemainingS: readInt(json['stepRemainingS']),
  );

  SequenceState copyWith({
    int? step,
    String? label,
    SequenceRunState? state,
    String? reason,
    bool clearReason = false,
    int? stepRemainingS,
  }) => SequenceState(
    programId: programId,
    name: name,
    step: step ?? this.step,
    of: of,
    label: label ?? this.label,
    state: state ?? this.state,
    reason: clearReason ? null : (reason ?? this.reason),
    stepRemainingS: stepRemainingS ?? this.stepRemainingS,
  );
}
