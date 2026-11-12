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

enum SequenceRunState { running, waitingStart, paused, done, aborted, unknown }

/// Fortschritt eines Programms auf der Brücke (intern „sequence“).
class SequenceState {
  const SequenceState({
    required this.programId,
    required this.step,
    required this.of,
    required this.state,
    this.reason,
  });

  final String programId;
  final int step;
  final int of;
  final SequenceRunState state;
  final String? reason;

  factory SequenceState.fromJson(Json json) => SequenceState(
    programId: readString(json['programId']),
    step: readInt(json['step']),
    of: readInt(json['of']),
    state: switch (json['state']) {
      'running' => SequenceRunState.running,
      'waiting_start' => SequenceRunState.waitingStart,
      'paused' => SequenceRunState.paused,
      'done' => SequenceRunState.done,
      'aborted' => SequenceRunState.aborted,
      _ => SequenceRunState.unknown,
    },
    reason: json['reason'] as String?,
  );
}
