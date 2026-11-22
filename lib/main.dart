import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/event_log.dart';
import 'core/storage/app_storage.dart';
import 'ui/illustrations.dart';
import 'version.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _logErrors();
  Illustrations.registerLicense();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
      child: const RuehrlinkApp(),
    ),
  );
}

/// Fehler und Ausnahmen zusätzlich ins Ereignisprotokoll („Problem melden“) – das Verhalten
/// sonst bleibt gleich (vorheriger Handler wird weiter aufgerufen).
void _logErrors() {
  appEvents.add('app', 'Start, Version $appVersion');
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    appEvents.add('fehler', details.exceptionAsString().split('\n').first);
    previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    appEvents.add(
      'fehler',
      'Unbehandelt: ${error.runtimeType}: ${'$error'.split('\n').first}',
    );
    return false; // wie bisher an die Standardbehandlung weitergeben
  };
}
