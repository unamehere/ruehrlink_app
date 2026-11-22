// F26: Ablauf bleibt bei „Knopf drücken“, obwohl die Maschine läuft (Sahne schlagen, KCL95).
// Stellt die Ereignisfolgen nach, bei denen die App den Wechsel auf „läuft“ verpassen konnte.
import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/core/api/bridge_api.dart';
import 'package:ruehrlink/core/api/bridge_providers.dart';
import 'package:ruehrlink/core/api/fake_bridge_api.dart';
import 'package:ruehrlink/core/models/models.dart';
import 'package:ruehrlink/features/kochen/programs.dart';
import 'package:ruehrlink/features/kochen/nachstellen.dart';
import 'package:ruehrlink/features/kochen/sequence_nudge.dart';
import 'package:ruehrlink/l10n/app_localizations.dart';

/// Brücke, deren Live-Kanal und `GET /sequence` der Test selbst steuert.
class _Api extends FakeBridgeApi {
  _Api() : super(latency: Duration.zero);

  final live = StreamController<BridgeEvent>.broadcast();
  SequenceState box = SequenceState.idle;
  int abfragen = 0;

  /// Was `POST /sequence/start` antwortet: Fehlercode (409) oder `null` = angenommen.
  String? startFehler;
  int starts = 0;

  @override
  Future<SequenceState> startSequence(Program program) async {
    starts++;
    if (startFehler != null) {
      throw BridgeException(BridgeErrorKind.rejected, 409, startFehler);
    }
    return box;
  }

  @override
  Stream<BridgeEvent> events() => live.stream;

  @override
  Future<SequenceState> sequence() async {
    abfragen++;
    return box;
  }

  void senden(BridgeEvent e) => live.add(e);
}

SequenceState seq(
  SequenceRunState state, {
  int step = 1,
  String? reason,
  int rest = 0,
}) => SequenceState(
  name: 'Sahne schlagen',
  step: step,
  of: 2,
  state: state,
  reason: reason,
  stepRemainingS: rest,
);

ApplianceStatus maschine({
  bool laeuft = false,
  bool aktiv = false,
  int rest = 0,
  bool kopfZu = true,
}) => ApplianceStatus(
  connected: true,
  running: laeuft,
  active: aktiv || laeuft,
  heating: false,
  hot: false,
  bowlFitted: true,
  lidClosed: kopfZu,
  bowlTemp: 20,
  tempSet: 0,
  speedSet: 8,
  remainingS: rest,
);

final l10n = lookupAppLocalizations(const Locale('de'));

/// Wie der Assistent „Sahne schlagen“: anschlagen (Stufe 3, 20 s), dann schlagen (max).
const sahne = Program(
  id: '',
  name: 'Sahne schlagen',
  steps: [
    ProgramStep(settings: MachineSettings(temperature: 0, time: 20, speed: 8)),
    ProgramStep(
      settings: MachineSettings(temperature: 0, time: 120, speed: 12),
    ),
  ],
);

void main() {
  late _Api api;
  late ProviderContainer c;
  final seen = <SequenceState>[];

  Future<void> warten() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    api = _Api();
    c = ProviderContainer(
      overrides: [bridgeApiProvider.overrideWithValue(api)],
    );
    seen.clear();
    c.listen(sequenceProvider, (_, n) {
      if (n.value != null) seen.add(n.value!);
    }, fireImmediately: true);
    await warten();
  });

  tearDown(() {
    c.dispose();
    api.close();
  });

  SequenceState? jetzt() => c.read(sequenceProvider).value;

  test('folgt den seq-Nachrichten der Box', () async {
    expect(jetzt()?.state, SequenceRunState.idle);
    api.senden(
      SequenceEvent(seq(SequenceRunState.waitingStart, reason: 'press_start')),
    );
    await warten();
    expect(jetzt()?.state, SequenceRunState.waitingStart);
    api.senden(SequenceEvent(seq(SequenceRunState.running, rest: 20)));
    await warten();
    expect(jetzt()?.state, SequenceRunState.running);
    expect(jetzt()?.stepRemainingS, 20);
  });

  test('nach dem Wiederverbinden wird der Stand neu geholt (verpasste seq-Nachricht)', () async {
    api.senden(
      SequenceEvent(seq(SequenceRunState.waitingStart, reason: 'press_start')),
    );
    await warten();
    // Live-Kanal bricht ab, in der Zeit läuft die Maschine los und die Box meldet „running“ – verpasst.
    api.senden(const ConnectionEvent(online: false));
    api.box = seq(SequenceRunState.running, rest: 18);
    final vorher = api.abfragen;
    api.senden(const ConnectionEvent(online: true));
    await warten();
    await warten();
    expect(api.abfragen, vorher + 1);
    expect(jetzt()?.state, SequenceRunState.running);
  });

  test(
    'auch ein verpasstes „fertig“ kommt nach dem Wiederverbinden an',
    () async {
      api.senden(
        SequenceEvent(seq(SequenceRunState.running, step: 2, rest: 5)),
      );
      await warten();
      api.box = seq(SequenceRunState.done, step: 2);
      api.senden(const ConnectionEvent(online: true));
      await warten();
      await warten();
      expect(jetzt()?.state, SequenceRunState.done);
    },
  );

  test('Box meldet „Knopf drücken“, Maschine läuft schon → App zeigt „läuft“ (F26)', () async {
    // Kopf offen → abgelehnt; Kopf zu, erneut gesendet; Box wartet auf den Knopf …
    api.senden(StatusEvent(maschine(kopfZu: false)));
    api.senden(StatusEvent(maschine()));
    api.senden(
      SequenceEvent(seq(SequenceRunState.waitingStart, reason: 'press_start')),
    );
    await warten();
    expect(jetzt()?.state, SequenceRunState.waitingStart);
    // … am Gerät gestartet, aber „running“ der Box kommt nie an.
    api.box = seq(SequenceRunState.waitingStart, reason: 'press_start');
    final vorher = api.abfragen;
    api.senden(StatusEvent(maschine(laeuft: true, rest: 20)));
    await warten();
    await warten();
    expect(api.abfragen, vorher + 1, reason: 'fragt bei der Box nach');
    expect(jetzt()?.state, SequenceRunState.running);
    expect(jetzt()?.reason, isNull);
    expect(jetzt()?.stepRemainingS, 20);
    // Restzeit läuft mit
    api.senden(StatusEvent(maschine(laeuft: true, rest: 19)));
    await warten();
    expect(jetzt()?.stepRemainingS, 19);
    // Rührintervall: Motor kurz aus, Programm aktiv → bleibt „läuft“
    api.senden(StatusEvent(maschine(aktiv: true, rest: 18)));
    await warten();
    expect(jetzt()?.state, SequenceRunState.running);
    // Die Box holt auf: ihr Stand gilt wieder
    api.senden(SequenceEvent(seq(SequenceRunState.running, rest: 17)));
    await warten();
    expect(jetzt()?.state, SequenceRunState.running);
    expect(jetzt()?.stepRemainingS, 17);
  });

  test('Maschine steht → „Knopf drücken“ bleibt', () async {
    api.senden(StatusEvent(maschine(rest: 20)));
    api.senden(
      SequenceEvent(seq(SequenceRunState.waitingStart, reason: 'press_start')),
    );
    await warten();
    expect(jetzt()?.state, SequenceRunState.waitingStart);
    // Kopf offen, Motor aus: nicht als „läuft“ deuten
    api.senden(StatusEvent(maschine(aktiv: true, rest: 20, kopfZu: false)));
    await warten();
    expect(jetzt()?.state, SequenceRunState.waitingStart);
  });

  test('Statusmeldungen ohne Änderung erzeugen keinen neuen Stand', () async {
    api.senden(
      SequenceEvent(seq(SequenceRunState.waitingStart, reason: 'press_start')),
    );
    await warten();
    final n = seen.length;
    api.senden(StatusEvent(maschine(rest: 20)));
    api.senden(StatusEvent(maschine(rest: 20)));
    await warten();
    expect(seen.length, n);
  });

  test('ältere Abfrage überschreibt keine neuere seq-Nachricht', () async {
    api.box = seq(SequenceRunState.waitingStart, reason: 'press_start');
    api.senden(const ConnectionEvent(online: true)); // Abfrage läuft …
    api.senden(
      SequenceEvent(seq(SequenceRunState.running, rest: 20)),
    ); // … Nachricht ist neuer
    await warten();
    await warten();
    expect(jetzt()?.state, SequenceRunState.running);
  });

  test(
    'Hinweis-Dialog ist überholt, sobald sich Zustand oder Schritt ändert',
    () {
      final wartet = seq(
        SequenceRunState.waitingStart,
        step: 2,
        reason: 'press_start',
      );
      expect(nudgeVeraltet(wartet, wartet), isFalse);
      expect(nudgeVeraltet(wartet, null), isFalse);
      expect(
        nudgeVeraltet(wartet, seq(SequenceRunState.running, step: 2)),
        isTrue,
      );
      expect(
        nudgeVeraltet(wartet, seq(SequenceRunState.done, step: 2)),
        isTrue,
      );
      expect(
        nudgeVeraltet(wartet, seq(SequenceRunState.waitingStart, step: 1)),
        isTrue,
      );
    },
  );

  test('F26: Start bei offenem Kopf abgelehnt → Kopf zu → erneut gesendet → am Gerät gestartet', () async {
    final ctl = c.read(sequenceControllerProvider);
    c.listen(applianceStatusProvider, (_, _) {});
    await warten();
    // 1. Schüssel drin, Kopf offen → Box lehnt ab, nichts geht an die Maschine
    api.senden(StatusEvent(maschine(kopfZu: false)));
    await warten();
    api.startFehler = 'not_ready';
    expect(await ctl.start(sahne, l10n), l10n.checkLid);
    expect(c.read(letzterLaufProvider), isNull);
    expect(
      jetzt()?.state,
      SequenceRunState.idle,
      reason: 'Ablehnung ändert den Stand nicht',
    );

    // 2. Kopf zu, erneut senden → angenommen, Box wartet auf den Knopf
    api.senden(StatusEvent(maschine()));
    api.startFehler = null;
    api.box = seq(SequenceRunState.waitingStart, reason: 'press_start');
    expect(await ctl.start(sahne, l10n), isNull);
    api.senden(SequenceEvent(api.box));
    await warten();
    expect(jetzt()?.state, SequenceRunState.waitingStart);
    expect(c.read(letzterLaufProvider)?.passt(jetzt()!), isTrue);

    // 3. Knopf am Gerät: Maschine läuft, aber „running“ der Box kommt nicht an (Box hängt oder Nachricht weg)
    api.senden(StatusEvent(maschine(laeuft: true, rest: 20)));
    await warten();
    await warten();
    expect(jetzt()?.state, SequenceRunState.running, reason: 'Uhr läuft');
    expect(jetzt()?.stepRemainingS, 20);

    // 4. Die Box holt auf und meldet am Ende „fertig“ → Nachstellen wird angeboten
    api.senden(
      SequenceEvent(seq(SequenceRunState.running, step: 2, rest: 120)),
    );
    api.senden(SequenceEvent(seq(SequenceRunState.done, step: 2)));
    await warten();
    expect(jetzt()?.state, SequenceRunState.done);
    expect(
      nachstellAngebot(jetzt(), c.read(letzterLaufProvider), null),
      isNotNull,
    );
  });

  testWidgets(
    'F26: Box bleibt bei „Knopf drücken“, Live-Nachrichten fehlen → regelmäßiger Abgleich holt den Stand',
    (tester) async {
      final a = _Api();
      final k = ProviderContainer(
        overrides: [bridgeApiProvider.overrideWithValue(a)],
      );
      k.listen(sequenceProvider, (_, _) {});
      await tester.pump();
      a.senden(
        SequenceEvent(
          seq(SequenceRunState.waitingStart, reason: 'press_start'),
        ),
      );
      await tester.pump();
      // Box ist weiter, aber keine Nachricht kommt an (auch kein Status)
      a.box = seq(SequenceRunState.running, rest: 15);
      await tester.pump(sequenceAbgleich + const Duration(milliseconds: 10));
      await tester.pump();
      expect(k.read(sequenceProvider).value?.state, SequenceRunState.running);
      // Ohne laufendes Programm wird nicht mehr gefragt
      a.box = seq(SequenceRunState.done, step: 2);
      await tester.pump(sequenceAbgleich);
      await tester.pump();
      expect(k.read(sequenceProvider).value?.state, SequenceRunState.done);
      final n = a.abfragen;
      await tester.pump(sequenceAbgleich * 3);
      expect(a.abfragen, n);
      k.dispose();
      a.close();
    },
  );
}
