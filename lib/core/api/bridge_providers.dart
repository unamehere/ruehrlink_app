import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../storage/app_storage.dart';
import 'bridge_api.dart';
import 'fake_bridge_api.dart';
import 'http_bridge_api.dart';

/// Mit welcher Brücke die App spricht. Ändern → alle abhängigen Provider bauen neu.
final bridgeTargetProvider =
    NotifierProvider<BridgeTargetNotifier, BridgeTarget>(
      BridgeTargetNotifier.new,
    );

class BridgeTargetNotifier extends Notifier<BridgeTarget> {
  @override
  BridgeTarget build() =>
      ref.read(appStorageProvider).bridge ?? const DemoTarget();

  Future<void> select(BridgeTarget target) async {
    state = target;
    await ref.read(appStorageProvider).setBridge(target);
  }

  /// Gespeicherte Brücke samt Token vergessen (z. B. nach dem Zurücksetzen).
  Future<void> forget() async {
    state = const DemoTarget();
    await ref.read(appStorageProvider).clearBridge();
  }
}

/// Die aktive [BridgeApi] – Demo (simuliert) oder echte Brücke im WLAN.
final bridgeApiProvider = Provider<BridgeApi>((ref) {
  final api = switch (ref.watch(bridgeTargetProvider)) {
    DemoTarget() => FakeBridgeApi(),
    final NetworkTarget t => HttpBridgeApi(t),
  };
  ref.onDispose(api.close);
  return api;
});

/// Brücke und Gerät inkl. `caps`. Wird neu geholt, wenn das Gerät sich
/// verbindet oder trennt – dann können sich die Fähigkeiten ändern.
final bridgeInfoProvider = FutureProvider<BridgeInfo>((ref) async {
  ref.listen(applianceStatusProvider.select((s) => s.value?.connected), (
    previous,
    next,
  ) {
    if (previous != null && next != null && previous != next) {
      ref.invalidateSelf();
    }
  });
  final api = ref.watch(bridgeApiProvider);
  final info = await api.info();
  // Bei jedem Verbinden die Uhrzeit übergeben; Fehler sind hier unkritisch.
  unawaited(api.setTime(DateTime.now()).catchError((Object _) {}));
  return info;
});

/// Live-Status: erst `GET /state`, dann jede `status`-Nachricht vom WebSocket.
/// Reißt der Live-Kanal ab (Box ausgesteckt), wird der Status zum Fehler („Rührlink nicht erreichbar“);
/// steht er wieder, holt die App den Stand neu.
final applianceStatusProvider = StreamProvider<ApplianceStatus>((ref) {
  final api = ref.watch(bridgeApiProvider);
  final out = StreamController<ApplianceStatus>();
  Future<void> fetch() async {
    try {
      final s = await api.state();
      if (!out.isClosed) out.add(s);
    } on BridgeException catch (e, st) {
      if (!out.isClosed) out.addError(e, st);
    }
  }

  // Der Stream liefert bei jeder Änderung den vollständigen Status – eine
  // kurze Lücke zwischen Abfrage und Abo ist daher unkritisch.
  final sub = api.events().listen((e) {
    switch (e) {
      case StatusEvent(:final status):
        out.add(status);
      case ConnectionEvent(online: false):
        out.addError(const BridgeException(BridgeErrorKind.unreachable));
      case ConnectionEvent(online: true):
        unawaited(fetch());
      default:
    }
  });
  unawaited(fetch());
  ref.onDispose(() {
    unawaited(sub.cancel());
    unawaited(out.close());
  });
  return out.stream;
});
