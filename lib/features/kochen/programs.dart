import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/event_log.dart';
import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import 'nachstellen.dart';

/// Stand des Programms auf der Brücke: `GET /sequence`, dann jede `seq`-Nachricht.
/// Ältere Firmware ohne Programme oder keine Brücke → [SequenceState.idle].
///
/// Abgesichert gegen verpasste Nachrichten (F26: Anzeige blieb bei „Knopf drücken“, obwohl die
/// Maschine lief):
/// - Live-Kanal wird zuerst abonniert, dann erst abgefragt – keine Lücke dazwischen.
/// - Nach jedem Wiederverbinden des Live-Kanals wird der Stand neu geholt.
/// - Meldet die Box „Knopf drücken“, während die Maschine laut Status schon läuft, fragt die App nach
///   und zeigt „läuft“ mit der Restzeit der Maschine ([sequenceMitMaschine]).
final sequenceProvider = StreamProvider<SequenceState>((ref) {
  final api = ref.watch(bridgeApiProvider);
  final out = StreamController<SequenceState>();
  SequenceState? box; // Stand laut Box
  SequenceState? shown; // zuletzt an die App gegeben
  ApplianceStatus? maschine;
  var abfrage =
      0; // nur die neueste Abfrage zählt; eine seq-Nachricht ist immer neuer
  DateTime? nachgefragt;

  void zeigen() {
    final b = box;
    if (b == null || out.isClosed) return;
    final s = sequenceMitMaschine(b, maschine, vorher: shown);
    final alt = shown;
    if (alt != null && _gleich(alt, s)) return;
    if (alt == null || alt.state != s.state || alt.step != s.step) {
      appEvents.add(
        'ablauf',
        '${s.state.name} Schritt ${s.step}/${s.of}'
            '${s.reason != null ? ' (${s.reason})' : ''}'
            '${s.state != b.state ? ' – Maschine läuft, Box meldet ${b.state.name}' : ''}',
      );
    }
    shown = s;
    out.add(s);
  }

  Future<void> holen(String anlass) async {
    final n = ++abfrage;
    try {
      final s = await api.sequence();
      if (n != abfrage) return;
      if (anlass.isNotEmpty && box != null && box!.state != s.state) {
        appEvents.add(
          'ablauf',
          '$anlass: Box meldet ${s.state.name} statt ${box!.state.name}',
        );
      }
      box = s;
    } on BridgeException {
      if (n != abfrage || box != null) return;
      box = SequenceState.idle;
    }
    zeigen();
  }

  final sub = api.events().listen((e) {
    switch (e) {
      case SequenceEvent(:final state):
        abfrage++; // laufende Abfrage ist älter als diese Nachricht
        box = state;
        zeigen();
      case StatusEvent(:final status):
        maschine = status;
        // Box wartet noch, Maschine läuft schon: Stand nachfragen (höchstens alle 3 s)
        final now = DateTime.now();
        if (box?.state == SequenceRunState.waitingStart &&
            maschineLaeuft(status) &&
            (nachgefragt == null ||
                now.difference(nachgefragt!) > const Duration(seconds: 3))) {
          nachgefragt = now;
          unawaited(holen('Maschine läuft'));
        }
        zeigen();
      case ConnectionEvent(online: true):
        unawaited(holen('Neu verbunden'));
      default:
    }
  });
  unawaited(holen(''));
  // Solange ein Programm läuft, regelmäßig abgleichen: gehen Nachrichten der Box verloren (z. B. knapper
  // Speicher, während nach dem Kopf-Hochklappen die Waage läuft), bleibt die Anzeige sonst stehen (F26).
  final abgleich = Timer.periodic(sequenceAbgleich, (_) {
    if (box?.active ?? false) unawaited(holen('Abgleich'));
  });
  ref.onDispose(() {
    abgleich.cancel();
    unawaited(sub.cancel());
    unawaited(out.close());
  });
  return out.stream;
});

/// Wie oft die App während eines Programms `GET /sequence` abfragt.
const sequenceAbgleich = Duration(seconds: 5);

bool _gleich(SequenceState a, SequenceState b) =>
    a.state == b.state &&
    a.step == b.step &&
    a.of == b.of &&
    a.reason == b.reason &&
    a.stepRemainingS == b.stepRemainingS &&
    a.name == b.name &&
    a.label == b.label &&
    a.programId == b.programId;

/// Dreht die Maschine laut Status gerade ein Programm (Motor an, Restzeit läuft)?
bool maschineLaeuft(ApplianceStatus s) =>
    s.connected &&
    s.running &&
    !s.keepWarm &&
    s.remainingS > 0 &&
    s.readyToStart;

/// Was die App anzeigt: der Stand der Box – außer die Box meldet „Knopf drücken“, während die Maschine
/// schon läuft (F26). Dann „läuft“ mit der Restzeit der Maschine. Einmal so erkannt, bleibt es dabei,
/// solange die Maschine aktiv ist (Rührintervalle schalten den Motor an und aus, F11).
SequenceState sequenceMitMaschine(
  SequenceState box,
  ApplianceStatus? maschine, {
  SequenceState? vorher,
}) {
  final m = maschine;
  if (box.state != SequenceRunState.waitingStart || m == null) return box;
  final schonAbgeleitet =
      vorher != null &&
      vorher.state == SequenceRunState.running &&
      vorher.step == box.step &&
      vorher.name == box.name;
  final laeuft =
      maschineLaeuft(m) ||
      (schonAbgeleitet &&
          m.connected &&
          (m.active || m.running) &&
          m.remainingS > 0);
  if (!laeuft) return box;
  return box.copyWith(
    state: SequenceRunState.running,
    clearReason: true,
    stepRemainingS: m.remainingS,
  );
}

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
