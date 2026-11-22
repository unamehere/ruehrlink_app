import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/event_log.dart';
import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import 'nachstellen.dart';

/// Stand des Programms auf der Brücke: erst `GET /sequence`, dann jede `seq`-Nachricht.
/// Ältere Firmware ohne Programme oder keine Brücke → [SequenceState.idle].
final sequenceProvider = StreamProvider<SequenceState>((ref) async* {
  final api = ref.watch(bridgeApiProvider);
  try {
    yield await api.sequence();
  } on BridgeException {
    yield SequenceState.idle;
  }
  SequenceState? last;
  await for (final e in api.events()) {
    if (e is SequenceEvent) {
      final s = e.state;
      if (last == null || last.state != s.state || last.step != s.step) {
        appEvents.add(
          'ablauf',
          '${s.state.name} Schritt ${s.step}/${s.of}'
              '${s.reason != null ? ' (${s.reason})' : ''}',
        );
      }
      last = s;
      yield s;
    }
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

/// Was vor dem Start fehlt – nur das nennen, was wirklich fehlt (Schüssel, Kopf oder beides).
/// Ohne bekannten Status der kombinierte Hinweis.
String bowlLidHint(ApplianceStatus? status, AppLocalizations l10n) =>
    switch ((status?.bowlFitted, status?.lidClosed)) {
      (true, false) => l10n.checkLid,
      (false, true) => l10n.checkBowl,
      _ => l10n.startNotReady,
    };

/// Ergebnis eines Startversuchs: `null` = gestartet, sonst Fehlermeldung.
typedef StartResult = String?;

final sequenceControllerProvider = Provider<SequenceController>(
  SequenceController.new,
);

class SequenceController {
  SequenceController(this.ref);
  final Ref ref;

  Future<StartResult> start(Program program, AppLocalizations l10n) => _start(
    program,
    l10n,
    bezugS: program.steps.isEmpty ? 0 : program.steps.last.settings.time,
  );

  /// Letzten Schritt des zuletzt hier gestarteten Programms noch [zusatzS] Sekunden laufen lassen
  /// (gleiche Stufe und Temperatur, siehe `nachstellen.dart`).
  Future<StartResult> nachstellen(int zusatzS, AppLocalizations l10n) {
    final lauf = ref.read(letzterLaufProvider);
    if (lauf == null) return Future.value(l10n.startFailed);
    return _start(nachstellProgramm(lauf, zusatzS), l10n, bezugS: lauf.bezugS);
  }

  Future<StartResult> _start(
    Program program,
    AppLocalizations l10n, {
    required int bezugS,
  }) async {
    appEvents.add(
      'ablauf',
      'Start „${program.name}“ (${program.steps.length} Schritte)',
    );
    try {
      await ref.read(bridgeApiProvider).startSequence(program);
      if (program.steps.isNotEmpty) {
        ref
            .read(letzterLaufProvider.notifier)
            .merken(LetzterLauf(programm: program, bezugS: bezugS));
      }
      return null;
    } on BridgeException catch (e) {
      appEvents.add('ablauf', 'Start abgelehnt: ${e.code ?? e.kind.name}');
      return switch ((e.kind, e.code, e.statusCode)) {
        (BridgeErrorKind.unreachable, _, _) => l10n.bridgeUnreachable,
        (_, 'not_ready', _) => bowlLidHint(
          ref.read(applianceStatusProvider).value,
          l10n,
        ),
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
    appEvents.add('ablauf', 'Abbrechen');
    try {
      await ref.read(bridgeApiProvider).abortSequence();
      return true;
    } on BridgeException catch (e) {
      return e.kind == BridgeErrorKind.rejected; // 409 = lief schon nicht mehr
    }
  }
}
