import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/version.dart';

void main() {
  test('appVersion passt zu pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final pubspec = line.split(':')[1].trim().split('+').first;
    expect(appVersion, pubspec);
  });

  test('eingebaute Firmware: Manifest und Datei passen zusammen', () {
    final manifest = jsonDecode(
      File('assets/firmware/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final bin = File('assets/firmware/${manifest['file']}');
    expect(bin.existsSync(), isTrue);
    expect(bin.lengthSync(), manifest['size']);
  });
}
