import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/core/event_log.dart';
import 'package:ruehrlink/core/models/models.dart';
import 'package:ruehrlink/features/mehr/problem_report.dart';

void main() {
  const token = '0123456789abcdef0123456789abcdef';

  group('EventLog', () {
    test('behält nur die letzten Einträge', () {
      final log = EventLog(capacity: 3);
      for (var i = 1; i <= 5; i++) {
        log.add('test', 'Ereignis $i');
      }
      expect(log.entries.map((e) => e.message), [
        'Ereignis 3',
        'Ereignis 4',
        'Ereignis 5',
      ]);
      expect(log.dropped, 2);
      log.clear();
      expect(log.entries, isEmpty);
      expect(log.dropped, 0);
    });

    test('zählt gleiche Meldungen direkt hintereinander zusammen', () {
      var t = DateTime(2026, 11, 23, 18, 4, 12);
      final log = EventLog(clock: () => t);
      log.add('api', 'GET info → nicht erreichbar');
      t = t.add(const Duration(seconds: 2));
      log.add('api', 'GET info → nicht erreichbar');
      t = t.add(const Duration(seconds: 2));
      log.add('api', 'GET info → nicht erreichbar');
      log.add('update', 'Neustart fertig');
      expect(log.entries, hasLength(2));
      expect(log.entries.first.count, 3);
      expect(
        log.lines().first,
        '2026-11-23 18:04:12.000 [api] GET info → nicht erreichbar (×3 bis 18:04:16)',
      );
    });

    test('kürzt sehr lange Meldungen', () {
      final log = EventLog()..add('fehler', 'x' * 1000);
      expect(log.entries.single.message.length, lessThan(310));
    });

    test('maskiert Zugangsdaten auch beim Hineinschreiben', () {
      final log = EventLog()
        ..add('test', 'Authorization: Bearer $token')
        ..add('test', '{"password":"geheim123","ssid":"Heimnetz"}')
        ..add('test', 'ws?token=$token');
      final all = log.lines().join('\n');
      expect(all, isNot(contains(token)));
      expect(all, isNot(contains('geheim123')));
      expect(all, contains('Heimnetz'));
    });
  });

  group('maskSecrets', () {
    test('Schlüsselwörter mit : oder =', () {
      expect(maskSecrets('pop=abc123xyz'), 'pop=***');
      expect(maskSecrets('"pass": "hunter22"'), '"pass": "***"');
      expect(maskSecrets('Passwort: lecker!'), 'Passwort: ***');
      expect(maskSecrets('psk=xyz secret=abc'), 'psk=*** secret=***');
    });

    test('lässt normale Sätze und lange Hashes stehen', () {
      const sha =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      expect(
        maskSecrets('WebSocket ohne gueltigen Token abgelehnt'),
        'WebSocket ohne gueltigen Token abgelehnt',
      );
      expect(maskSecrets('media $sha'), 'media $sha');
      expect(maskSecrets('"keepWarm":false'), '"keepWarm":false');
      expect(maskSecrets('monkey: 5'), 'monkey: 5');
    });

    test('32-stellige Hex-Folgen und genannte Geheimnisse', () {
      expect(maskSecrets('token $token da'), 'token *** da');
      expect(
        maskSecrets('Code k3jd8a2mxz im Text', secrets: ['k3jd8a2mxz', null]),
        'Code *** im Text',
      );
    });
  });

  group('ProblemReport', () {
    ProblemReport report({
      String description = 'Waage bleibt bei 0 g stehen.',
      Json? diag,
      String? diagNote,
      List<String> events = const [],
    }) => ProblemReport(
      createdAt: DateTime(2026, 11, 23, 18, 4, 9),
      description: description,
      appVersion: '0.4.0',
      device: 'Google Pixel 8a, Android 15 (SDK 35)',
      target: const NetworkTarget(
        host: '192.168.1.40',
        token: token,
        id: '98C0',
        name: 'Rührlink',
      ),
      info: const BridgeInfo(
        id: '98C0',
        name: 'Rührlink',
        fw: '0.5.0',
        api: 1,
        features: {'machine', 'diag'},
        appliance: ApplianceInfo(paired: true, connected: true),
      ),
      status: ApplianceStatus.disconnected,
      diag: diag,
      diagNote: diagNote,
      events: events,
    );

    test('Dateiname und Betreff', () {
      final r = report();
      expect(r.fileName, 'ruehrlink-bericht-2026-11-23-1804.txt');
      expect(r.subject, contains('App 0.4.0'));
      expect(r.subject, contains('Firmware 0.5.0'));
    });

    test('enthält Beschreibung, Versionen, Status, Ereignisse und Box-Log', () {
      final text = report(
        diag: {
          'fw': '0.5.0',
          'uptimeS': 99,
          'resetReason': 'brownout',
          'log': 'I (5) kenwood: *** Maschine verbunden ***\n',
        },
        events: ['2026-11-23 18:00:00.000 [verbindung] Live-Verbindung steht'],
      ).toText();
      expect(text, contains('Waage bleibt bei 0 g stehen.'));
      expect(text, contains('Version: 0.4.0'));
      expect(text, contains('Google Pixel 8a, Android 15 (SDK 35)'));
      expect(text, contains('192.168.1.40:80'));
      expect(text, contains('"fw": "0.5.0"'));
      expect(text, contains('"features"'));
      expect(text, contains('"bowlTemp"'));
      expect(text, contains('Live-Verbindung steht'));
      expect(text, contains('"resetReason": "brownout"'));
      expect(text, contains('-- Box-Log --'));
      expect(text, contains('Maschine verbunden'));
    });

    test('ohne /diag: Hinweis „Box-Log nicht verfügbar“', () {
      final text = report(diagNote: 'Update nötig').toText();
      expect(text, contains('Box-Log nicht verfügbar: Update nötig'));
      expect(text, isNot(contains('-- Box-Log --')));
    });

    test('Token und Passwörter stehen nie drin', () {
      final text = report(
        description: 'Mein WLAN-Passwort: geheim123, Token $token',
        diag: {
          'log':
              'I (1) net: verbinde, password=geheim123\n'
              'I (2) api: Authorization: Bearer $token\n',
        },
        events: ['[api] GET info mit token=$token'],
      ).toText();
      expect(text, isNot(contains(token)));
      expect(text, isNot(contains('geheim123')));
      // Was nicht geheim ist, bleibt lesbar.
      expect(text, contains('Mein WLAN-Passwort: ***'));
      expect(text, contains('I (1) net: verbinde'));
    });

    test('Demo-Modus ohne Token', () {
      final r = ProblemReport(
        createdAt: DateTime(2026, 11, 23),
        description: '',
        appVersion: '0.4.0',
        device: 'Test',
        target: const DemoTarget(),
        infoError: 'unreachable',
      );
      final text = r.toText();
      expect(text, contains('Demo-Modus'));
      expect(text, contains('(keine)'));
      expect(text, contains('nicht abrufbar: unreachable'));
      expect(r.subject, contains('Firmware ?'));
    });

    test('Mail-Text wird gekürzt und bekommt den Hinweis', () {
      final r = report(diag: {'log': 'I (1) x: ${'Zeile\n' * 2000}'});
      final body = r.mailBody(hint: 'GEKÜRZT', maxChars: 500);
      expect(body, startsWith('GEKÜRZT'));
      expect(body.length, lessThan(600));
      expect(body, contains('Waage bleibt bei 0 g stehen.'));
      final short = report().mailBody(hint: 'GEKÜRZT', maxChars: 100000);
      expect(short, isNot(contains('GEKÜRZT')));
    });
  });
}
