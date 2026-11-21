import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/core/update/firmware.dart';
import 'package:ruehrlink/version.dart';

void main() {
  test('appVersion passt zu pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final pubspec = line.split(':')[1].trim().split('+').first;
    expect(appVersion, pubspec);
  });

  test('eingebaute Firmware: genau eine gültige Update-Datei', () {
    final files = Directory('assets/firmware')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.rlfw'))
        .toList();
    if (files.isEmpty) {
      markTestSkipped('keine eingebaute Firmware (Entwickler-Build)');
      return;
    }
    expect(files, hasLength(1));
    final pkg = FirmwarePackage.verify(files.single.readAsBytesSync());
    expect(
      files.single.path,
      endsWith('ruehrlink-${pkg.manifest.version}.rlfw'),
    );
  });
}
