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
final bridgeInfoProvider = FutureProvider<BridgeInfo>((ref) {
  ref.listen(applianceStatusProvider.select((s) => s.value?.connected), (
    previous,
    next,
  ) {
    if (previous != null && next != null && previous != next) {
      ref.invalidateSelf();
    }
  });
  return ref.watch(bridgeApiProvider).info();
});

/// Live-Status: erst `GET /state`, dann jede `status`-Nachricht vom WebSocket.
final applianceStatusProvider = StreamProvider<ApplianceStatus>((ref) async* {
  final api = ref.watch(bridgeApiProvider);
  yield await api.state();
  // Der Stream liefert bei jeder Änderung den vollständigen Status – eine
  // kurze Lücke zwischen Abfrage und Abo ist daher unkritisch.
  await for (final e in api.events()) {
    if (e is StatusEvent) yield e.status;
  }
});
