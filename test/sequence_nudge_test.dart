import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/core/models/models.dart';
import 'package:ruehrlink/features/kochen/sequence_nudge.dart';

SequenceState s(SequenceRunState state, {int step = 1, String? reason}) =>
    SequenceState(step: step, of: 3, state: state, reason: reason);

void main() {
  test('meldet nur, wenn die Maschine auf einen wartet', () {
    const r = SequenceRunState.running;
    const w = SequenceRunState.waitingStart;
    const p = SequenceRunState.paused;

    // Pause zu Ende: lief → wartet auf Knopf
    expect(shouldNudge(s(r), s(w, step: 2, reason: 'press_start')), isTrue);
    // fertig, unerwarteter Abbruch
    expect(shouldNudge(s(r), s(SequenceRunState.done)), isTrue);
    expect(
      shouldNudge(s(r), s(SequenceRunState.aborted, reason: 'disconnected')),
      isTrue,
    );

    // Nicht: Start, Kopf auf, Kopf wieder zu, selbst abgebrochen
    expect(
      shouldNudge(SequenceState.idle, s(w, reason: 'press_start')),
      isFalse,
    );
    expect(shouldNudge(s(r), s(p, reason: 'lid_open')), isFalse);
    expect(
      shouldNudge(s(p, reason: 'lid_open'), s(w, reason: 'press_start')),
      isFalse,
    );
    expect(
      shouldNudge(s(r), s(SequenceRunState.aborted, reason: 'user')),
      isFalse,
    );
  });
}
