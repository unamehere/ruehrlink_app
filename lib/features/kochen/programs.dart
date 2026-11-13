import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/models/models.dart';
import '../../l10n/l10n.dart';

/// Stand des Programms auf der Brücke: erst `GET /sequence`, dann jede `seq`-Nachricht.
/// Ältere Firmware ohne Programme oder keine Brücke → [SequenceState.idle].
final sequenceProvider = StreamProvider<SequenceState>((ref) async* {
  final api = ref.watch(bridgeApiProvider);
  try {
    yield await api.sequence();
  } on BridgeException {
    yield SequenceState.idle;
  }
  await for (final e in api.events()) {
    if (e is SequenceEvent) yield e.state;
  }
});

/// Auf der Brücke gespeicherte Programme (`GET /programs`), leer bei älterer Firmware.
final bridgeProgramsProvider = FutureProvider<List<Program>>((ref) async {
  try {
    return await ref.watch(bridgeApiProvider).programs();
  } on BridgeException {
    return const [];
  }
});

/// Testprogramme für die Inbetriebnahme an der Maschine (Testplan 3b). Die Stufen
/// kommen aus `caps` – nichts Gerätespezifisches fest im Code.
List<Program> testPrograms(ApplianceCaps caps, AppLocalizations l10n) {
  final c = caps.speedsIn(SpeedGroup.continuous);
  final off = caps.speedsIn(SpeedGroup.off);
  if (c.length < 6) return const [];
  ProgramStep run(SpeedOption o, int s) => ProgramStep(
    settings: MachineSettings(temperature: 0, time: s, speed: o.v),
    label: l10n.testStepSpeed(o.label),
  );
  return [
    Program(
      id: 'test-zwei-stufen',
      name: l10n.testTwoSpeeds,
      steps: [run(c[1], 20), run(c[3], 20)],
    ),
    if (off.isNotEmpty)
      Program(
        id: 'test-ruhephase',
        name: l10n.testWithRest,
        steps: [
          run(c[1], 15),
          ProgramStep(
            settings: MachineSettings(
              temperature: 0,
              time: 15,
              speed: off.first.v,
            ),
            label: l10n.testStepRest,
          ),
          run(c[1], 15),
        ],
      ),
    Program(
      id: 'test-rampe',
      name: l10n.testRamp,
      steps: [run(c[1], 15), run(c[5], 15)],
    ),
  ];
}

/// Ergebnis eines Startversuchs: `null` = gestartet, sonst Fehlermeldung.
typedef StartResult = String?;

final sequenceControllerProvider = Provider<SequenceController>(
  SequenceController.new,
);

class SequenceController {
  SequenceController(this.ref);
  final Ref ref;

  Future<StartResult> start(Program program, AppLocalizations l10n) async {
    try {
      await ref.read(bridgeApiProvider).startSequence(program);
      return null;
    } on BridgeException catch (e) {
      return switch ((e.kind, e.code, e.statusCode)) {
        (BridgeErrorKind.unreachable, _, _) => l10n.bridgeUnreachable,
        (_, 'not_ready', _) => l10n.startNotReady,
        (_, 'busy', _) => l10n.programBusy,
        (_, 'not_connected', _) => l10n.machineNotConnected,
        (_, 'hot_speed', _) => l10n.startHotSpeed,
        (_, null, 404) => l10n.startOldFirmware,
        (BridgeErrorKind.rejected, _, _) => l10n.startInvalid,
        _ => l10n.startFailed,
      };
    }
  }

  /// Abbrechen; `false`, wenn die Brücke nicht erreichbar war.
  Future<bool> abort() async {
    try {
      await ref.read(bridgeApiProvider).abortSequence();
      return true;
    } on BridgeException catch (e) {
      return e.kind == BridgeErrorKind.rejected; // 409 = lief schon nicht mehr
    }
  }
}
