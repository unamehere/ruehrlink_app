// Nachstellen: „Noch nicht fertig?“ → letzten Schritt kurz wiederholen (Sprint-Plan 23.11., Abschnitt 6).
import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/core/api/fake_bridge_api.dart';
import 'package:ruehrlink/core/models/models.dart';
import 'package:ruehrlink/features/kochen/nachstellen.dart';

const caps = FakeBridgeApi.demoCaps;

MachineSettings m(int speed, int time, {int temp = 0}) =>
    MachineSettings(temperature: temp, time: time, speed: speed);

LetzterLauf lauf(List<MachineSettings> schritte, {String name = 'Sahne'}) =>
    LetzterLauf(
      programm: Program(
        id: '',
        name: name,
        steps: [
          for (final (i, s) in schritte.indexed)
            ProgramStep(settings: s, label: 'Schritt $i'),
        ],
      ),
      bezugS: schritte.last.time,
    );

SequenceState fertig(String name, int of) =>
    SequenceState(name: name, step: of, of: of, state: SequenceRunState.done);

void main() {
  test('Zeitschritte passend zur Schrittdauer', () {
    // kurz (< 3 min): +30 s / +1 min
    expect(nachstellZeiten(m(12, 90), bezugS: 90, caps: caps), (30, 60));
    expect(nachstellZeiten(m(12, 179), bezugS: 179, caps: caps), (30, 60));
    // länger: +1 / +5 min
    expect(nachstellZeiten(m(6, 180), bezugS: 180, caps: caps), (60, 300));
    expect(nachstellZeiten(m(6, 420), bezugS: 420, caps: caps), (60, 300));
    // nach dem Nachstellen zählt die ursprüngliche Dauer
    expect(nachstellZeiten(m(6, 60), bezugS: 420, caps: caps), (60, 300));
    // Gehen mit Wärme, Motor aus: +5 / +10 min
    expect(nachstellZeiten(m(0, 1800, temp: 35), bezugS: 1800, caps: caps), (
      300,
      600,
    ));
    // Motor aus ohne Wärme nimmt die Brücke nicht an (first_step) → nicht anbieten
    expect(nachstellZeiten(m(0, 300), bezugS: 300, caps: caps), isNull);
    expect(
      nachstellZeiten(m(0, 300), bezugS: 300),
      isNull,
    ); // ohne caps: 0 = aus
  });

  test('Nachstell-Programm: letzter Schritt, gleiche Stufe/Temperatur/Beschriftung, neue Zeit', () {
    final l = lauf([m(8, 20), m(12, 90)]);
    final p = nachstellProgramm(l, 30);
    expect(p.name, 'Sahne');
    expect(p.id, '');
    expect(p.steps, hasLength(1));
    expect(p.steps.single.settings, m(12, 30));
    expect(p.steps.single.label, 'Schritt 1');

    final heiss = lauf([m(4, 420, temp: 50)], name: 'Schokolade');
    expect(
      nachstellProgramm(heiss, 60).steps.single.settings,
      m(4, 60, temp: 50),
    );
  });

  test('angeboten nur für den eigenen, fertigen Lauf', () {
    final l = lauf([m(8, 20), m(12, 90)]);
    expect(nachstellAngebot(fertig('Sahne', 2), l, caps), (30, 60));
    // läuft noch / abgebrochen
    expect(
      nachstellAngebot(
        const SequenceState(
          name: 'Sahne',
          step: 2,
          of: 2,
          state: SequenceRunState.running,
        ),
        l,
        caps,
      ),
      isNull,
    );
    expect(
      nachstellAngebot(
        const SequenceState(
          name: 'Sahne',
          step: 2,
          of: 2,
          state: SequenceRunState.aborted,
          reason: 'user',
        ),
        l,
        caps,
      ),
      isNull,
    );
    // anderes Programm (z. B. von einem anderen Handy) oder nichts gestartet
    expect(nachstellAngebot(fertig('Eischnee', 2), l, caps), isNull);
    expect(nachstellAngebot(fertig('Sahne', 3), l, caps), isNull);
    expect(nachstellAngebot(fertig('Sahne', 2), null, caps), isNull);
  });
}
