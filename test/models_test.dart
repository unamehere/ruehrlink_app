// JSON-Modelle gegen die Beispiele aus freikoch_esp/docs/api.md.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freikoch/core/models/models.dart';

Json _json(String s) => jsonDecode(s) as Json;

void main() {
  test('GET /info mit caps', () {
    const raw = '''
{
  "id": "98C0",
  "name": "Freikoch Brücke",
  "fw": "0.1.0",
  "api": 1,
  "storage": {"backend": "sd", "totalKB": 30000000, "freeKB": 29000000},
  "appliance": {
    "paired": true,
    "connected": true,
    "caps": {
      "model": "kenwood-kcl95",
      "name": "Cooking Chef XL",
      "tempMin": 20, "tempMax": 180,
      "speeds": [
        {"v": 0, "label": "Aus", "group": "off"},
        {"v": 13, "label": "1", "group": "stir"},
        {"v": 1, "label": "min", "group": "continuous"},
        {"v": 11, "label": "max", "group": "continuous"}
      ],
      "timeMaxS": 28800,
      "hasScale": true,
      "remoteStart": false
    }
  }
}''';
    final info = BridgeInfo.fromJson(_json(raw));
    expect(info.id, '98C0');
    expect(info.storage!.freeKB, 29000000);
    final caps = info.readyCaps!;
    expect(caps.tempMin, 20);
    expect(caps.tempMax, 180);
    expect(caps.speeds, hasLength(4));
    expect(caps.speedOption(13)!.group, SpeedGroup.stir);
    expect(caps.speedLabel(11), 'max');
    expect(caps.speedLabel(42), '42'); // unbekannt → Zahl
    expect(caps.timeMaxS, 28800);
    expect(caps.remoteStart, isFalse);
    // Rundreise: toJson ergibt wieder dasselbe JSON.
    expect(info.toJson(), _json(raw));
  });

  test('WebSocket-Nachrichten', () {
    final status = BridgeEvent.fromJson(
      _json(
        '{"t":"status","d":{"bowlTemp":23,"speedSet":0,"remainingS":0,'
        '"running":false,"heating":true,"hot":false,"tempSet":100,'
        '"bowlFitted":true,"lidClosed":true,"connected":true}}',
      ),
    );
    expect(status, isA<StatusEvent>());
    final s = (status as StatusEvent).status;
    expect(s.bowlTemp, 23);
    expect(s.lidClosed, isTrue);
    expect(s.heating, isTrue);
    expect(s.tempSet, 100);
    expect(s.readyToStart, isTrue);
    expect(s.toJson()['lidClosed'], isTrue);

    final weight = BridgeEvent.fromJson(
      _json('{"t":"weight","d":{"g":251.4}}'),
    );
    expect((weight as WeightEvent).grams, 251.4);

    final seq = BridgeEvent.fromJson(
      _json(
        '{"t":"seq","d":{"programId":"dinkelteig","step":2,"of":4,'
        '"state":"waiting_start","reason":null}}',
      ),
    );
    expect((seq as SequenceEvent).state.state, SequenceRunState.waitingStart);
    expect(seq.state.of, 4);

    final ack = BridgeEvent.fromJson(
      _json('{"t":"ack","d":{"cmd":"setProgramme","ok":true}}'),
    );
    expect((ack as AckEvent).cmd, AckEvent.setProgramme);

    final recipes = BridgeEvent.fromJson(
      _json('{"t":"recipes","d":{"rev":42}}'),
    );
    expect((recipes as RecipesChangedEvent).rev, 42);

    // Unbekannte Typen einer neueren Brücke sind kein Fehler.
    expect(
      BridgeEvent.fromJson(_json('{"t":"neu","d":{}}')),
      isA<UnknownEvent>(),
    );
  });

  test('Rezept mit Wiege-, Programm- und Einzelwert-Schritt', () {
    const raw = '''
{
  "id": "uuid",
  "rev": 7,
  "updated": "2026-11-12T10:00:00.000Z",
  "title": "Dinkel-Brot",
  "servings": 4,
  "photo": "sha256",
  "tags": ["Brot", "Teig"],
  "ingredients": [{"amount": 500, "unit": "g", "name": "Dinkelmehl 630"}],
  "steps": [
    {"text": "Mehl in die Schüssel wiegen.", "photo": null, "weigh": {"target": 500, "unit": "g"}},
    {"text": "Kneten.", "machine": {"programId": "dinkelteig"}},
    {"text": "Kurz rühren.", "machine": {"temperature": 0, "time": 60, "speed": 2}}
  ]
}''';
    final r = Recipe.fromJson(_json(raw));
    expect(r.updated, DateTime.utc(2026, 11, 12, 10));
    expect(r.steps[0].weigh!.target, 500);
    expect(r.steps[1].machine!.programId, 'dinkelteig');
    expect(
      r.steps[2].machine!.settings,
      const MachineSettings(temperature: 0, time: 60, speed: 2),
    );
    final back = r.toJson();
    expect(back['ingredients'], _json(raw)['ingredients']);
    expect((back['steps'] as List)[2], (_json(raw)['steps'] as List)[2]);
  });

  test('Programm', () {
    const raw = '''
{
  "id": "dinkelteig",
  "name": "Dinkelteig kneten",
  "scaleBy": {"ingredient": "flour", "baseGrams": 500},
  "steps": [
    {"speed": 1, "time": 60,  "temperature": 0, "label": "Unterrühren"},
    {"speed": 2, "time": 300, "temperature": 0, "label": "Kneten"},
    {"speed": 0, "time": 600, "temperature": 0, "label": "Ruhen"},
    {"speed": 2, "time": 120, "temperature": 0, "label": "Nachkneten"}
  ]
}''';
    final p = Program.fromJson(_json(raw));
    expect(p.steps, hasLength(4));
    expect(p.totalTime, 1080);
    expect(p.scaleBy!.baseGrams, 500);
    expect(p.toJson(), _json(raw));
  });
}
