import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pointycastle/digests/sha256.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/models/models.dart';
import '../../core/storage/recipe_store.dart';

/// Abgleich-Stand eines Rezepts (F21). Gespeichert wird nur direkt auf der Brücke – eine Kopie
/// ist also entweder auf dem Stand des Rührlinks, wird gerade abgeglichen oder ist nur zum Lesen da.
enum RecipeSyncStatus {
  /// Gleich mit dem Rührlink (letzter Abgleich ok).
  synced,

  /// Abgleich läuft.
  syncing,

  /// Rührlink nicht erreichbar – gezeigt wird die gespeicherte Kopie.
  offline,
}

/// Rezeptbibliothek, wie die App sie gerade kennt: lokale Kopie, abgeglichen mit der Brücke.
class RecipeLibraryState {
  const RecipeLibraryState({
    this.rev = 0,
    this.recipes = const {},
    this.loading = false,
    this.offline = false,
    this.syncing = false,
  });

  /// Stand der Bibliothek auf der Brücke, bis zu dem die Kopie reicht.
  final int rev;
  final Map<String, Recipe> recipes;

  /// Erster Abgleich läuft noch.
  final bool loading;

  /// Letzter Abgleich ging nicht (Brücke nicht erreichbar) – gezeigt wird die lokale Kopie.
  final bool offline;

  /// Ein (weiterer) Abgleich läuft gerade.
  final bool syncing;

  RecipeSyncStatus get syncStatus => loading || syncing
      ? RecipeSyncStatus.syncing
      : offline
      ? RecipeSyncStatus.offline
      : RecipeSyncStatus.synced;

  RecipeLibraryState copyWith({
    Map<String, Recipe>? recipes,
    bool? loading,
    bool? offline,
    bool? syncing,
  }) => RecipeLibraryState(
    rev: rev,
    recipes: recipes ?? this.recipes,
    loading: loading ?? this.loading,
    offline: offline ?? this.offline,
    syncing: syncing ?? this.syncing,
  );

  /// Alphabetisch nach Titel.
  List<Recipe> get sorted => recipes.values.toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  /// Alle vorkommenden Tags, alphabetisch.
  List<String> get tags =>
      {for (final r in recipes.values) ...r.tags}.toList()..sort();
}

final recipeLibraryProvider =
    NotifierProvider<RecipeLibrary, RecipeLibraryState>(RecipeLibrary.new);

/// Abgleich mit der Brücke über Revisionen (`GET /recipes?since=`), Speichern mit `If-Match`.
///
/// Speichern geht nur, wenn die Brücke erreichbar ist – offline ist die Kopie nur zum Lesen
/// da. So gibt es keine Warteschlange, die später still etwas überschreibt.
class RecipeLibrary extends Notifier<RecipeLibraryState> {
  late BridgeApi _api;
  late RecipeStore _store;
  late String _key;
  Future<void>? _running;
  bool _again = false;

  @override
  RecipeLibraryState build() {
    _api = ref.watch(bridgeApiProvider);
    _store = ref.watch(recipeStoreProvider);
    _key = switch (ref.watch(bridgeTargetProvider)) {
      DemoTarget() => 'demo',
      final NetworkTarget t => t.id ?? '${t.host}_${t.port}',
    };
    final sub = _api.events().listen((e) {
      if (e is RecipesChangedEvent && e.rev != state.rev) unawaited(sync());
    });
    ref.onDispose(sub.cancel);
    unawaited(_start());
    return const RecipeLibraryState(loading: true);
  }

  Future<void> _start() async {
    final cached = await _store.load(_key);
    if (!ref.mounted) return;
    if (cached != null && state.rev == 0) {
      state = RecipeLibraryState(
        rev: cached.rev,
        recipes: {for (final r in cached.recipes) r.id: r},
        loading: true,
      );
    }
    await sync();
  }

  /// Änderungen holen. Läuft schon ein Abgleich, folgt danach genau einer.
  Future<void> sync() async {
    if (_running != null) {
      _again = true;
      return _running;
    }
    if (ref.mounted) state = state.copyWith(syncing: true);
    final run = _running = _sync();
    try {
      await run;
    } finally {
      _running = null;
    }
    if (_again && ref.mounted) {
      _again = false;
      await sync();
    }
  }

  Future<void> _sync() async {
    try {
      var since = state.rev;
      var changes = await _api.recipeChanges(since);
      if (changes.rev < since) {
        // Andere Brücke oder Speicher getauscht → alles neu.
        since = 0;
        changes = await _api.recipeChanges(0);
      }
      if (!ref.mounted) return;
      final next = since == 0 ? <String, Recipe>{} : {...state.recipes};
      for (final r in changes.changed) {
        next[r.id] = r;
      }
      for (final id in changes.deleted) {
        next.remove(id);
      }
      state = RecipeLibraryState(rev: changes.rev, recipes: next);
      await _store.save(
        _key,
        CachedLibrary(rev: changes.rev, recipes: next.values.toList()),
      );
    } on BridgeException {
      if (ref.mounted) {
        state = state.copyWith(loading: false, offline: true, syncing: false);
      }
    }
  }

  /// Foto (WebP) hochladen und lokal ablegen; liefert den SHA-256 für [Recipe.photo].
  /// Vor dem Speichern des Rezepts aufrufen. Nicht erreichbar/zu groß → [BridgeException].
  Future<String> uploadPhoto(Uint8List webp) async {
    final sha = sha256Hex(webp);
    await _api.putMedia(sha, webp);
    await _store.saveMedia(sha, webp);
    return sha;
  }

  /// Auf der Brücke speichern (`If-Match` = [Recipe.rev], 0 = neu). War jemand anderes
  /// schneller, kommt [RecipeConflict] zurück und nichts wird überschrieben – „trotzdem
  /// speichern“ = noch einmal mit `rev` = `currentRev`. Nicht erreichbar → [BridgeException].
  Future<RecipeWriteResult> save(Recipe r) async {
    final result = await _api.putRecipe(r);
    if (result is RecipeWritten && ref.mounted) {
      final saved = r.copyWith(
        rev: result.rev,
        updated: result.updated ?? DateTime.now().toUtc(),
      );
      state = state.copyWith(recipes: {...state.recipes, saved.id: saved});
      // Bibliotheks-Revision erst über den Abgleich – sonst fehlten Änderungen anderer dazwischen.
      unawaited(sync());
    }
    return result;
  }

  /// Löschen mit `If-Match`; [RecipeConflict], wenn es inzwischen geändert wurde.
  Future<RecipeWriteResult> delete(Recipe recipe) async {
    RecipeWriteResult result;
    try {
      result = await _api.deleteRecipe(recipe.id, rev: recipe.rev);
    } on BridgeException catch (e) {
      if (e.statusCode != 404) rethrow;
      result = RecipeWritten(rev: recipe.rev); // war schon weg
    }
    if (result is RecipeWritten && ref.mounted) {
      state = state.copyWith(recipes: {...state.recipes}..remove(recipe.id));
      unawaited(sync());
    }
    return result;
  }
}

/// Ein Rezept aus der Bibliothek, `null` wenn es (nicht mehr) da ist.
final recipeProvider = Provider.family<Recipe?, String>(
  (ref, id) => ref.watch(recipeLibraryProvider.select((s) => s.recipes[id])),
);

/// Foto zu einem SHA-256: erst aus dem Zwischenspeicher, sonst von der Brücke.
final recipePhotoProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  sha256,
) async {
  final store = ref.watch(recipeStoreProvider);
  final cached = await store.loadMedia(sha256);
  if (cached != null) return cached;
  try {
    final bytes = await ref.watch(bridgeApiProvider).media(sha256);
    await store.saveMedia(sha256, bytes);
    return bytes;
  } on BridgeException {
    return null;
  }
});

// ---------------------------------------------------------------------------
// Helfer

String sha256Hex(Uint8List bytes) => SHA256Digest()
    .process(bytes)
    .map((b) => b.toRadixString(16).padLeft(2, '0'))
    .join();

/// Neue Rezept-ID (UUID v4) – passt zu den Regeln der Brücke (a-z, 0-9, „-“).
String newRecipeId([Random? random]) {
  final rnd = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Text auf höchstens [maxBytes] UTF-8-Bytes kürzen, ohne ein Zeichen zu zerschneiden
/// (Namen und Schrittbezeichnungen haben auf der Brücke feste Puffer).
String fitUtf8(String s, int maxBytes) {
  final out = StringBuffer();
  var used = 0;
  for (final r in s.runes) {
    final n = r < 0x80
        ? 1
        : r < 0x800
        ? 2
        : r < 0x10000
        ? 3
        : 4;
    if (used + n > maxBytes) break;
    used += n;
    out.writeCharCode(r);
  }
  return out.toString();
}

/// Menge für [servings] statt [base] Portionen.
double scaleAmount(double amount, int base, int servings) =>
    base <= 0 ? amount : amount * servings / base;

/// Menge lesbar runden: ab 100 auf 5, ab 10 auf ganze, darunter auf eine Nachkommastelle.
/// `0` = ohne Mengenangabe → leer.
String formatAmount(double v) {
  if (v <= 0) return '';
  final rounded = v >= 100
      ? (v / 5).round() * 5.0
      : v >= 10
      ? v.roundToDouble()
      : (v * 10).round() / 10;
  return NumberFormat('0.#', 'de').format(rounded);
}

/// Zutat als Zeile: „750 g Mehl“, „Prise Salz“.
String ingredientText(Ingredient i, double factor) {
  final amount = formatAmount(i.amount * factor);
  return [
    if (amount.isNotEmpty) amount,
    if (amount.isNotEmpty && i.unit.isNotEmpty) i.unit,
    i.name,
  ].join(' ');
}
