// Grenzwerte kommen aus den caps – auch für ein anderes Gerät.
import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/core/models/models.dart';
import 'package:ruehrlink/features/maschine/regler.dart';
import 'package:ruehrlink/ui/input.dart';

const caps = ApplianceCaps(
  model: 'test',
  name: 'Testgerät',
  tempMin: 37,
  tempMax: 120,
  speeds: [
    SpeedOption(v: 9, label: 'P', group: SpeedGroup.stir),
    SpeedOption(v: 0, label: 'Aus', group: SpeedGroup.off),
    SpeedOption(v: 1, label: 'min', group: SpeedGroup.continuous),
    SpeedOption(v: 5, label: 'max', group: SpeedGroup.continuous),
  ],
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
      const MachineSettings(temperature: 120, time: 3600, speed: 9),
    );
    // Unter tempMin heißt „Heizung aus“, nicht tempMin.
    expect(caps.clampTemperature(30), 0);
    // Nur Stufen aus der Liste – keine Zahlenskala.
    expect(caps.clampSpeed(5), 5);
    expect(caps.clampSpeed(3), 0);
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

  test('Zeit stoppt an den Grenzen', () {
    expect(Regler.time(caps, 0, up: false), isNull);
    expect(Regler.time(caps, 0, up: true), 10);
    expect(Regler.time(caps, 120, up: false), 110);
    expect(Regler.time(caps, 3600, up: true), isNull);
  });

  test('Eingetippte Werte: gültig übernehmen, ungültig ablehnen', () {
    expect(Regler.parseTemperature(caps, ''), 0); // leer = aus
    expect(Regler.parseTemperature(caps, '0'), 0);
    expect(Regler.parseTemperature(caps, '100'), 100);
    expect(Regler.parseTemperature(caps, '30'), isNull); // unter tempMin
    expect(Regler.parseTemperature(caps, '130'), isNull); // über tempMax
    expect(formatDurationDigits('130'), '1:30');
    expect(formatDurationDigits('13000'), '1:30:00');
    expect(Regler.parseTime(caps, '1:30'), 90);
    expect(Regler.parseTime(caps, '1:75'), isNull);
    expect(Regler.parseTime(caps, '1:00:01'), isNull); // über timeMaxS
  });
}
