import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage/app_storage.dart';
import 'ui/illustrations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Illustrations.registerLicense();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
      child: const RuehrlinkApp(),
    ),
  );
}
