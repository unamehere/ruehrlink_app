// Update-Datei .rlfw lokal prüfen (ruehrlink_esp/docs/updates.md). Eine gültige Signatur kann
// hier nicht entstehen – der private Schlüssel liegt nie im Repo; das prüft der Test an der Maschine.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruehrlink/core/update/firmware.dart';

Uint8List _rlfw(Map<String, Object?> manifest, List<int> image) {
  final a = Archive()
    ..add(ArchiveFile.string('manifest.json', jsonEncode(manifest)))
    ..add(ArchiveFile.bytes('ruehrlink-9.9.9.bin', image));
  return Uint8List.fromList(ZipEncoder().encode(a));
}

FirmwareFileError? _error(Uint8List rlfw) {
  try {
    FirmwarePackage.verify(rlfw);
    return null;
  } on FirmwareFileException catch (e) {
    return e.error;
  }
}

void main() {
  final image = List<int>.generate(1000, (i) => i % 251);
  Map<String, Object?> manifest({int? size, String? sha}) => {
    'version': '9.9.9',
    'api': 1,
    'minApp': '0.1.0',
    'notes': 'Test',
    'file': 'ruehrlink-9.9.9.bin',
    'size': size ?? image.length,
    'sha256': sha ?? sha256.convert(image).toString(),
    'sig': '00' * 64,
  };

  test('keine Update-Datei', () {
    expect(_error(Uint8List.fromList([1, 2, 3])), FirmwareFileError.invalid);
    expect(
      _error(_rlfw({'version': '1.0.0'}, image)),
      FirmwareFileError.invalid,
    );
  });

  test('beschädigt: Größe oder Prüfsumme passen nicht', () {
    expect(_error(_rlfw(manifest(size: 5), image)), FirmwareFileError.damaged);
    expect(
      _error(_rlfw(manifest(sha: '00' * 32), image)),
      FirmwareFileError.damaged,
    );
  });

  test('falsche Signatur', () {
    expect(_error(_rlfw(manifest(), image)), FirmwareFileError.signature);
    final m = FirmwarePackage.readManifest(_rlfw(manifest(), image));
    expect(m.version, '9.9.9');
    expect(m.channel, 'stable');
    expect(m.security, isFalse);
  });

  test('Versionen vergleichen', () {
    expect(compareVersions('0.3.3', '0.4.0'), -1);
    expect(compareVersions('0.10.0', '0.9.9'), 1);
    expect(compareVersions('0.4.0-dirty', '0.4.0'), 0);
    // Testversionen (Release Candidates)
    expect(compareVersions('0.6.1-rc.1', '0.6.1'), -1);
    expect(compareVersions('0.6.1', '0.6.1-rc.2'), 1);
    expect(compareVersions('0.6.1-rc.1', '0.6.1-rc.2'), -1);
    expect(compareVersions('0.6.1-rc.2', '0.6.0'), 1);
    expect(compareVersions('0.6.1-rc.1', '0.6.1-rc.1'), 0);
  });
}
