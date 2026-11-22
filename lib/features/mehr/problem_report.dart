import 'dart:convert';

import '../../core/event_log.dart';
import '../../core/models/models.dart';

/// Inhalt von „Problem melden“: Beschreibung + Diagnose als ein Text, den der Nutzer vor dem
/// Versenden komplett sieht. Reine Logik ohne Flutter, damit sie sich testen lässt.
///
/// Abschnittsüberschriften sind fest (Deutsch): Der Bericht ist ein technisches Dokument für die
/// Auswertung, keine Oberfläche.
class ProblemReport {
  ProblemReport({
    required this.createdAt,
    required this.description,
    required this.appVersion,
    required this.device,
    required this.target,
    this.info,
    this.infoError,
    this.status,
    this.statusError,
    this.diag,
    this.diagNote,
    this.events = const [],
    this.droppedEvents = 0,
    this.screenshot = false,
  });

  final DateTime createdAt;
  final String description;
  final String appVersion;

  /// Handy und Betriebssystem, z. B. „Google Pixel 8a, Android 15 (SDK 35)“.
  final String device;
  final BridgeTarget target;
  final BridgeInfo? info;
  final String? infoError;
  final ApplianceStatus? status;
  final String? statusError;

  /// Antwort von `GET /diag` – `null`, wenn die Firmware das nicht kann oder der Rührlink nicht antwortet.
  final Json? diag;

  /// Warum es kein Box-Log gibt.
  final String? diagNote;
  final List<String> events;
  final int droppedEvents;
  final bool screenshot;

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// `ruehrlink-bericht-2026-11-23-1804.txt`
  String get fileName {
    final t = createdAt;
    return 'ruehrlink-bericht-${t.year}-${_two(t.month)}-${_two(t.day)}-'
        '${_two(t.hour)}${_two(t.minute)}.txt';
  }

  String get firmware => info?.fw ?? diag?['fw'] as String? ?? '?';

  /// Betreff für Mail/Teilen.
  String get subject =>
      'Rührlink – Problem (App $appVersion, Firmware $firmware)';

  String get _connection => switch (target) {
    DemoTarget() => 'Demo-Modus (kein Rührlink)',
    final NetworkTarget t =>
      'Rührlink ${t.name ?? t.id ?? ''} unter ${t.host}:${t.port}'.replaceAll(
        '  ',
        ' ',
      ),
  };

  /// Alle Werte, die nie im Bericht stehen dürfen (der Token der App).
  List<String?> get _secrets => [
    if (target case NetworkTarget(:final token)) token,
  ];

  /// Der komplette Bericht – genau das wird verschickt.
  String toText() {
    const enc = JsonEncoder.withIndent('  ');
    final t = createdAt;
    final b = StringBuffer()
      ..writeln('Rührlink – Problembericht')
      ..writeln(
        'Erstellt: ${t.year}-${_two(t.month)}-${_two(t.day)} '
        '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)} '
        '(UTC${t.timeZoneOffset.isNegative ? '-' : '+'}'
        '${_two(t.timeZoneOffset.inHours.abs())})',
      )
      ..writeln()
      ..writeln('== Beschreibung ==')
      ..writeln(description.trim().isEmpty ? '(keine)' : description.trim())
      ..writeln(screenshot ? '(Bild angehängt)' : '')
      ..writeln('== App ==')
      ..writeln('Version: $appVersion')
      ..writeln('Gerät: $device')
      ..writeln('Verbindung: $_connection')
      ..writeln()
      ..writeln('== Rührlink (GET /info) ==')
      ..writeln(
        info != null
            ? enc.convert(info!.toJson())
            : '(nicht abrufbar: ${infoError ?? '?'})',
      )
      ..writeln()
      ..writeln('== Maschinenstatus (GET /state) ==')
      ..writeln(
        status != null
            ? enc.convert(status!.toJson())
            : '(nicht abrufbar: ${statusError ?? '?'})',
      )
      ..writeln()
      ..writeln('== App-Ereignisse (letzte ${events.length}) ==');
    if (droppedEvents > 0) {
      b.writeln('($droppedEvents ältere nicht mehr gespeichert)');
    }
    if (events.isEmpty) b.writeln('(keine)');
    for (final e in events) {
      b.writeln(e);
    }
    b
      ..writeln()
      ..writeln('== Rührlink-Diagnose (GET /diag) ==');
    final d = diag;
    if (d == null) {
      b.writeln(
        'Box-Log nicht verfügbar${diagNote != null ? ': $diagNote' : ''}',
      );
    } else {
      final rest = Map<String, dynamic>.of(d)..remove('log');
      b
        ..writeln(enc.convert(rest))
        ..writeln()
        ..writeln('-- Box-Log --')
        ..write(d['log'] is String ? d['log'] as String : '(leer)');
    }
    return '${maskSecrets(b.toString().trimRight(), secrets: _secrets)}\n';
  }

  /// Mail-Text für `mailto:` – Anhänge gehen dort nicht, also gekürzt auf [maxChars]
  /// (lange mailto-Links scheitern in manchen Mail-Apps). [hint] steht vor dem gekürzten Teil.
  String mailBody({required String hint, int maxChars = 1800}) {
    final full = toText();
    if (full.length <= maxChars) return full;
    return '$hint\n\n${full.substring(0, maxChars)}\n…';
  }
}
