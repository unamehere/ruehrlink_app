import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Eine im Heim-WLAN gefundene Brücke (mDNS `_freikoch._tcp`).
class DiscoveredBridge {
  const DiscoveredBridge({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.fw,
    this.api,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String? fw;
  final int? api;
}

/// Brücken im WLAN finden. Kleine Schnittstelle, damit das mDNS-Paket
/// austauschbar bleibt und Tests ohne Netzwerk laufen.
abstract class BridgeDiscovery {
  /// Liefert die jeweils aktuelle Liste gefundener Brücken, solange gehört wird.
  Stream<List<DiscoveredBridge>> scan();
}

/// mDNS über `bonsoir` (Android NSD, Apple Bonjour).
class BonsoirBridgeDiscovery implements BridgeDiscovery {
  static const serviceType = '_freikoch._tcp';

  @override
  Stream<List<DiscoveredBridge>> scan() {
    final found = <String, DiscoveredBridge>{};
    late final StreamController<List<DiscoveredBridge>> out;
    BonsoirDiscovery? discovery;
    StreamSubscription<BonsoirDiscoveryEvent>? sub;

    Future<void> start() async {
      final d = BonsoirDiscovery(type: serviceType);
      discovery = d;
      await d.initialize();
      sub = d.eventStream?.listen((event) {
        switch (event) {
          case BonsoirDiscoveryServiceFoundEvent(:final service):
            unawaited(service.resolve(d.serviceResolver));
          case BonsoirDiscoveryServiceResolvedEvent(:final service) ||
              BonsoirDiscoveryServiceUpdatedEvent(:final service):
            final bridge = _toBridge(service);
            if (bridge != null) found[service.name] = bridge;
          case BonsoirDiscoveryServiceLostEvent(:final service):
            found.remove(service.name);
          default:
            return;
        }
        if (!out.isClosed) out.add(List.unmodifiable(found.values));
      });
      await d.start();
    }

    out = StreamController(
      onListen: () => unawaited(start().catchError(out.addError)),
      onCancel: () async {
        await sub?.cancel();
        await discovery?.stop();
      },
    );
    return out.stream;
  }

  static DiscoveredBridge? _toBridge(BonsoirService s) {
    // IPv4 bevorzugen – die Brücke spricht im MVP nur IPv4.
    final host =
        s.hostAddresses.where((a) => a.contains('.')).firstOrNull ??
        s.hostAddress;
    if (host == null) return null;
    final txt = s.attributes;
    return DiscoveredBridge(
      id: txt['id'] ?? s.name,
      name: txt['name'] ?? s.name,
      host: host,
      port: s.port,
      fw: txt['fw'],
      api: int.tryParse(txt['api'] ?? ''),
    );
  }
}

final bridgeDiscoveryProvider = Provider<BridgeDiscovery>(
  (ref) => BonsoirBridgeDiscovery(),
);
