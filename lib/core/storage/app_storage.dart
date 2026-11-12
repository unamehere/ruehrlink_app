import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/json.dart';
import '../models/models.dart';

/// Lokale Einstellungen der App. Fürs MVP genügt `shared_preferences`.
///
/// Offen: Den Token später im sicheren Speicher (Keychain/Keystore) ablegen.
class AppStorage {
  AppStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _kBridge = 'bridge';
  static const _kSetupDone = 'setupDone';

  /// Zuletzt verwendete Brücke (inkl. Token) oder `null`.
  BridgeTarget? get bridge {
    final raw = _prefs.getString(_kBridge);
    if (raw == null) return null;
    try {
      return BridgeTarget.fromJson(readMap(jsonDecode(raw)));
    } on FormatException {
      return null;
    }
  }

  Future<void> setBridge(BridgeTarget target) =>
      _prefs.setString(_kBridge, jsonEncode(target.toJson()));

  /// Einrichtung beim ersten Start abgeschlossen?
  bool get setupDone => _prefs.getBool(_kSetupDone) ?? false;

  Future<void> setSetupDone(bool done) => _prefs.setBool(_kSetupDone, done);
}

/// Wird in `main.dart` mit der geladenen Instanz überschrieben.
final appStorageProvider = Provider<AppStorage>(
  (ref) => throw UnimplementedError('appStorageProvider in main() setzen'),
);
