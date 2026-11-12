// Grenzwerte kommen aus den caps – auch für ein anderes Gerät.
import 'package:flutter_test/flutter_test.dart';
import 'package:freikoch/core/models/models.dart';
import 'package:freikoch/features/maschine/regler.dart';

const caps = ApplianceCaps(
  model: 'test',
  name: 'Testgerät',
  tempMin: 37,
  tempMax: 120,
  speedMax: 6,
  timeMaxS: 3600,
  hasScale: false,
  remoteStart: false,
);

void main() {
  test('clamp hält alle Werte in den Grenzen', () {
    expect(
      caps.clamp(
        const MachineSettings(temperature: 200, time: 99999, speed: 9),
      ),
      const MachineSettings(temperature: 120, time: 3600, speed: 6),
    );
    // Unter tempMin heißt „Heizung aus“, nicht tempMin.
    expect(caps.clampTemperature(30), 0);
    expect(caps.clampSpeed(-1), 0);
  });

  test('Temperatur: aus, tempMin, 5er-Schritte, tempMax', () {
    expect(Regler.temperature(caps, 0, up: true), 37);
    expect(Regler.temperature(caps, 37, up: true), 40);
    expect(Regler.temperature(caps, 40, up: false), 37);
    expect(Regler.temperature(caps, 37, up: false), 0);
    expect(Regler.temperature(caps, 0, up: false), isNull);
    expect(Regler.temperature(caps, 118, up: true), 120);
    expect(Regler.temperature(caps, 120, up: true), isNull);
  });

  test('Zeit und Stufe stoppen an den Grenzen', () {
    expect(Regler.time(caps, 0, up: false), isNull);
    expect(Regler.time(caps, 0, up: true), 10);
    expect(Regler.time(caps, 120, up: false), 110);
    expect(Regler.time(caps, 3600, up: true), isNull);
    expect(Regler.speed(caps, 6, up: true), isNull);
    expect(Regler.speed(caps, 0, up: false), isNull);
    expect(Regler.speed(caps, 3, up: true), 4);
  });
}
