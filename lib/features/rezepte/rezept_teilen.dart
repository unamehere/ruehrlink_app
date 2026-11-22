import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/bridge_api.dart';
import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import 'recipe_library.dart';
import 'rezept_datei.dart';

/// Eine empfangene oder gewählte Rezept-Datei, die auf die Vorschau wartet.
class RezeptEingang {
  const RezeptEingang({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Datei für die Vorschau „Rezept übernehmen“ (`/rezepte/uebernehmen`). Bleibt stehen, bis sie
/// übernommen oder verworfen ist – auch wenn der Rührlink gerade nicht erreichbar ist.
final rezeptEingangProvider =
    NotifierProvider<RezeptEingangNotifier, RezeptEingang?>(
      RezeptEingangNotifier.new,
    );

class RezeptEingangNotifier extends Notifier<RezeptEingang?> {
  @override
  RezeptEingang? build() => null;

  void set(RezeptEingang? e) => state = e;
}

/// Pfad der Vorschau.
const rezeptUebernehmenPfad = '/rezepte/uebernehmen';

// ---------------------------------------------------------------------------
// Teilen

/// Rezept als `.rlrezept` ins Teilen-Menü des Systems geben (Fotos eingebettet).
/// Die Datei liegt nur im Temp-Ordner der App.
Future<void> teileRezept(WidgetRef ref, Recipe recipe, {Rect? origin}) async {
  final photos = <String, Uint8List>{};
  for (final sha in {?recipe.photo, for (final s in recipe.steps) ?s.photo}) {
    final bytes = await ref.read(recipePhotoProvider(sha).future);
    if (bytes != null) photos[sha] = bytes;
  }
  final bytes = RezeptDatei.schreiben(recipe, photos);
  final dir = await Directory('${(await getTemporaryDirectory()).path}/teilen')
      .create(recursive: true);
  // Alte geteilte Dateien wegräumen – sie werden nur für den einen Vorgang gebraucht.
  for (final f in dir.listSync().whereType<File>()) {
    try {
      f.deleteSync();
    } on FileSystemException {
      // egal
    }
  }
  final file = File('${dir.path}/${rezeptDateiName(recipe.title)}');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: rezeptDateiMime)],
      subject: recipe.title,
      sharePositionOrigin: origin,
    ),
  );
}

// ---------------------------------------------------------------------------
// Öffnen

/// Datei wählen (Rezeptliste → „Rezept-Datei öffnen“) und zur Vorschau.
Future<void> oeffneRezeptDatei(BuildContext context, WidgetRef ref) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    // Ohne Typ-Filter: Android kennt die Endung nicht und würde sonst alles ausblenden.
    // Ob es ein Rezept ist, prüft die Vorschau am Inhalt.
    final file = await openFile();
    if (file == null) return;
    if (await file.length() > RezeptGrenzen.dateiBytes) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.recipeFileTooBig)));
      return;
    }
    ref
        .read(rezeptEingangProvider.notifier)
        .set(RezeptEingang(name: file.name, bytes: await file.readAsBytes()));
    router.go(rezeptUebernehmenPfad);
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.recipeFileReadFailed)));
  }
}

/// Kanal zu MainActivity.kt: „Öffnen mit Rührlink“ (VIEW) und Teilen an Rührlink (SEND).
const _kanal = MethodChannel('de.ruehrlink.app/rezept_datei');

/// Holt Dateien ab, die Android an die App übergibt, und öffnet die Vorschau. Liegt im Rahmen der
/// Tabs, also erst nach der Einrichtung aktiv – eine vorher empfangene Datei wartet so lange.
class RezeptEmpfangWatcher extends ConsumerStatefulWidget {
  const RezeptEmpfangWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RezeptEmpfangWatcher> createState() =>
      _RezeptEmpfangWatcherState();
}

class _RezeptEmpfangWatcherState extends ConsumerState<RezeptEmpfangWatcher> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb || !Platform.isAndroid) return;
    _kanal.setMethodCallHandler((call) async {
      if (call.method == 'available') await _abholen();
    });
    _abholen();
  }

  @override
  void dispose() {
    if (!kIsWeb && Platform.isAndroid) _kanal.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _abholen() async {
    Map<String, Object?>? m;
    try {
      m = await _kanal.invokeMapMethod<String, Object?>('pending');
    } on MissingPluginException {
      return;
    } on PlatformException {
      m = const {'error': 'read'};
    }
    if (m == null || !mounted) return;
    final bytes = m['bytes'];
    if (bytes is! Uint8List) {
      final l10n = context.l10n;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            m['error'] == 'size'
                ? l10n.recipeFileTooBig
                : l10n.recipeFileReadFailed,
          ),
        ),
      );
      return;
    }
    ref
        .read(rezeptEingangProvider.notifier)
        .set(
          RezeptEingang(
            name: m['name'] is String ? m['name']! as String : '',
            bytes: bytes,
          ),
        );
    GoRouter.of(context).go(rezeptUebernehmenPfad);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ---------------------------------------------------------------------------
// Grundrezepte

/// Ordner der mitgelieferten Grundrezepte (pubspec.yaml).
const grundrezepteOrdner = 'assets/rezepte/';

/// Alle mitgelieferten Grundrezepte lesen (kaputte überspringen – darf nicht vorkommen, prüft ein Test).
Future<List<RezeptDatei>> ladeGrundrezepte([AssetBundle? bundle]) async {
  final b = bundle ?? rootBundle;
  final manifest = await AssetManifest.loadFromAssetBundle(b);
  final pfade =
      manifest
          .listAssets()
          .where(
            (p) =>
                p.startsWith(grundrezepteOrdner) &&
                p.endsWith(rezeptDateiEndung),
          )
          .toList()
        ..sort();
  final out = <RezeptDatei>[];
  for (final p in pfade) {
    try {
      final data = await b.load(p);
      out.add(RezeptDatei.lesen(data.buffer.asUint8List()));
    } on RezeptDateiException {
      continue;
    }
  }
  return out;
}

/// „Grundrezepte hinzufügen“ (leere Liste, Menü der Rezeptliste): fehlende anlegen, Meldung.
Future<void> grundrezepteHinzufuegen(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final dateien = await ladeGrundrezepte();
    final n = await ref
        .read(recipeLibraryProvider.notifier)
        .grundrezepteHinzufuegen(dateien);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          n == 0 ? l10n.recipeBasicsNone : l10n.recipeBasicsAdded(n),
        ),
      ),
    );
  } on BridgeException catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e.kind == BridgeErrorKind.rejected
              ? l10n.recipeFileRejected(e.code ?? '${e.statusCode}')
              : l10n.bridgeUnreachable,
        ),
      ),
    );
  }
}
