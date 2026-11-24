import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/json.dart';
import '../models/models.dart';

/// Lokale Kopie der Rezeptbibliothek einer Brücke, Stand [rev].
class CachedLibrary {
  const CachedLibrary({required this.rev, required this.recipes});

  final int rev;
  final List<Recipe> recipes;

  Json toJson() => {
    'v': 1,
    'rev': rev,
    'recipes': [for (final r in recipes) r.toJson()],
  };

  factory CachedLibrary.fromJson(Json json) => CachedLibrary(
    rev: readInt(json['rev']),
    recipes: readList(json['recipes'], Recipe.fromJson),
  );
}

/// Zwischenspeicher der App für Rezepte (je Brücke) und Fotos (nach SHA-256, für alle gleich).
///
/// Nur eine Kopie – die Brücke ist die Quelle der Wahrheit. Fehler beim Lesen oder Schreiben
/// werden verschluckt: dann holt die App eben alles neu.
abstract class RecipeStore {
  Future<CachedLibrary?> load(String key);
  Future<void> save(String key, CachedLibrary library);
  Future<Uint8List?> loadMedia(String sha256);
  Future<void> saveMedia(String sha256, Uint8List bytes);
}

/// Dateien im App-Support-Verzeichnis: `recipes/library_<key>.json`, `recipes/media/<sha>.webp`.
class FileRecipeStore implements RecipeStore {
  FileRecipeStore({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _baseDir;
  Directory? _dir;

  Future<Directory?> _root() async {
    try {
      return _dir ??= await Directory(
        '${(await _baseDir()).path}/recipes/media',
      ).create(recursive: true).then((d) => d.parent);
    } on Object {
      return null; // z. B. in Tests ohne Plugin
    }
  }

  static String _safe(String key) =>
      key.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// Erst daneben schreiben, dann umbenennen – nie eine halbe Datei.
  static Future<void> _writeAtomic(File f, List<int> bytes) async {
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<CachedLibrary?> load(String key) async {
    final dir = await _root();
    if (dir == null) return null;
    try {
      final f = File('${dir.path}/library_${_safe(key)}.json');
      if (!f.existsSync()) return null;
      return CachedLibrary.fromJson(
        readMap(jsonDecode(await f.readAsString())),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(String key, CachedLibrary library) async {
    final dir = await _root();
    if (dir == null) return;
    try {
      await _writeAtomic(
        File('${dir.path}/library_${_safe(key)}.json'),
        utf8.encode(jsonEncode(library.toJson())),
      );
    } on Object {
      // nur Zwischenspeicher
    }
  }

  @override
  Future<Uint8List?> loadMedia(String sha256) async {
    final dir = await _root();
    if (dir == null) return null;
    try {
      final f = File('${dir.path}/media/${_safe(sha256)}.webp');
      return f.existsSync() ? await f.readAsBytes() : null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveMedia(String sha256, Uint8List bytes) async {
    final dir = await _root();
    if (dir == null) return;
    try {
      await _writeAtomic(
        File('${dir.path}/media/${_safe(sha256)}.webp'),
        bytes,
      );
    } on Object {
      // nur Zwischenspeicher
    }
  }
}

/// Nur im Speicher – für Tests.
class MemoryRecipeStore implements RecipeStore {
  final libraries = <String, CachedLibrary>{};
  final media = <String, Uint8List>{};

  @override
  Future<CachedLibrary?> load(String key) async => libraries[key];

  @override
  Future<void> save(String key, CachedLibrary library) async =>
      libraries[key] = library;

  @override
  Future<Uint8List?> loadMedia(String sha256) async => media[sha256];

  @override
  Future<void> saveMedia(String sha256, Uint8List bytes) async =>
      media[sha256] = bytes;
}

final recipeStoreProvider = Provider<RecipeStore>((ref) => FileRecipeStore());
