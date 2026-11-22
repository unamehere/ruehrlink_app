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

  Future<void> clearBridge() => _prefs.remove(_kBridge);

  /// Einrichtung beim ersten Start abgeschlossen?
  bool get setupDone => _prefs.getBool(_kSetupDone) ?? false;

  Future<void> setSetupDone(bool done) => _prefs.setBool(_kSetupDone, done);

  static const _kNudgeVibration = 'nudgeVibration';
  static const _kNudgeBigHint = 'nudgeBigHint';

  /// Vibration bei Hinweisen: 0 aus, 1 normal, 2 kräftig.
  int get nudgeVibration => _prefs.getInt(_kNudgeVibration) ?? 1;
  Future<void> setNudgeVibration(int v) => _prefs.setInt(_kNudgeVibration, v);

  /// Großer Hinweis auf dem Bildschirm.
  bool get nudgeBigHint => _prefs.getBool(_kNudgeBigHint) ?? true;
  Future<void> setNudgeBigHint(bool on) => _prefs.setBool(_kNudgeBigHint, on);

  static const _kScalePopup = 'scalePopup';

  /// Waage im Koch-Tab automatisch zeigen, wenn der Kopf der Maschine hochgeklappt wird.
  bool get scalePopup => _prefs.getBool(_kScalePopup) ?? true;
  Future<void> setScalePopup(bool on) => _prefs.setBool(_kScalePopup, on);

  static const _kWeighAutoNext = 'weighAutoNext';

  /// Kochmodus: nach erreichter Zielmenge von selbst zur nächsten Zutat (ab Werk aus).
  bool get weighAutoNext => _prefs.getBool(_kWeighAutoNext) ?? false;
  Future<void> setWeighAutoNext(bool on) => _prefs.setBool(_kWeighAutoNext, on);

  static const _kSafetyHints = 'safetyHints';

  /// Sicherheitshinweise: 0 alle, 1 nur kritische, 2 aus.
  int get safetyHints => _prefs.getInt(_kSafetyHints) ?? 0;
  Future<void> setSafetyHints(int v) => _prefs.setInt(_kSafetyHints, v);

  static const _kFeatureHintFw = 'featureHintFw';

  /// Firmware-Version, zu der der Hinweis „Dafür braucht dein Rührlink ein Update“ schon kam.
  String? get featureHintFw => _prefs.getString(_kFeatureHintFw);
  Future<void> setFeatureHintFw(String fw) =>
      _prefs.setString(_kFeatureHintFw, fw);
}

/// Wird in `main.dart` mit der geladenen Instanz überschrieben.
final appStorageProvider = Provider<AppStorage>(
  (ref) => throw UnimplementedError('appStorageProvider in main() setzen'),
);
