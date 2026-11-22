import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/api/http_bridge_api.dart';
import '../../core/discovery/bridge_discovery.dart';
import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/hilfe_knopf.dart';
import '../hilfe/hilfe_themen.dart';
import '../../ui/layout.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import '../../ui/widgets/hint_card.dart';
import 'storage_row.dart';

/// Brücke wählen: Demo-Modus, im WLAN gefunden (mDNS) oder IP von Hand.
/// Bei einer echten Brücke folgt die Kopplung aus api.md: Anfrage stellen, ein
/// schon gekoppeltes Handy bestätigt (im Entwicklermodus auch die BOOT-Taste).
class VerbindungPage extends ConsumerStatefulWidget {
  const VerbindungPage({super.key});

  static const pairTimeout = Duration(seconds: 60);
  static const pairInterval = Duration(seconds: 2);

  @override
  ConsumerState<VerbindungPage> createState() => _VerbindungPageState();
}

class _VerbindungPageState extends ConsumerState<VerbindungPage> {
  late final Stream<List<DiscoveredBridge>> _found = ref
      .read(bridgeDiscoveryProvider)
      .scan();
  final _host = TextEditingController();
  NetworkTarget? _pairing;
  String? _error;

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  Future<void> _useDemo() async {
    await ref.read(bridgeTargetProvider.notifier).select(const DemoTarget());
    if (mounted) context.go('/maschine');
  }

  /// Kopplung anfragen und alle 2 s nachfragen, bis bestätigt oder abgelaufen.
  Future<void> _pair(NetworkTarget target) async {
    final l10n = context.l10n;
    setState(() {
      _pairing = target;
      _error = null;
    });
    final api = HttpBridgeApi(target);
    final attempts =
        VerbindungPage.pairTimeout.inSeconds ~/
        VerbindungPage.pairInterval.inSeconds;
    String? error = l10n.connectionPairTimeout;
    try {
      final id = await api.requestPairing(await deviceName());
      for (var i = 0; i < attempts && mounted && _pairing == target; i++) {
        await Future<void>.delayed(VerbindungPage.pairInterval);
        if (!mounted || _pairing != target) break;
        final token = await api.pollPairing(id);
        if (token == null) continue;
        await ref
            .read(bridgeTargetProvider.notifier)
            .select(target.withToken(token));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.connectionPaired(target.name ?? target.host)),
          ),
        );
        context.go('/maschine');
        return;
      }
    } on BridgeException catch (e) {
      error = e.kind == BridgeErrorKind.rejected
          ? l10n.connectionPairTimeout
          : l10n.bridgeUnreachableHint;
    } finally {
      api.close();
    }
    if (mounted && _pairing == target) {
      setState(() {
        _pairing = null;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final current = ref.watch(bridgeTargetProvider);
    final storage = ref.watch(bridgeInfoProvider).value?.storage;

    if (_pairing != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.connectionPairTitle),
          actions: const [HilfeKnopf(hilfeKopplungBestaetigen)],
        ),
        body: AdaptivePage(
          primary: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HintCard(
                icon: Icons.phonelink_lock_rounded,
                text: l10n.connectionPairTitle,
                detail: l10n.connectionPairText,
                emphasized: true,
              ),
              const SizedBox(height: Tokens.xl),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: Tokens.xl),
              // Nur für Entwicklung: Firmware im Entwicklermodus.
              Text(
                l10n.connectionPairDevHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          bottom: BigButton(
            label: l10n.back,
            kind: BigButtonKind.secondary,
            onPressed: () => setState(() => _pairing = null),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.connectionTitle),
        actions: const [HilfeKnopf(hilfeVerbindung)],
      ),
      body: AdaptivePage(
        primary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.connectionCurrent, style: theme.textTheme.titleMedium),
            const SizedBox(height: Tokens.s),
            Card(
              child: ListTile(
                leading: Icon(
                  current is DemoTarget
                      ? Icons.science_outlined
                      : Icons.router_rounded,
                  size: 32,
                ),
                title: Text(switch (current) {
                  DemoTarget() => l10n.connectionDemo,
                  NetworkTarget(:final name, :final host) => name ?? host,
                }),
                subtitle: Text(switch (current) {
                  DemoTarget() => l10n.connectionDemoText,
                  NetworkTarget(:final host) => host,
                }),
              ),
            ),
            // Fehlt `storage` (ältere Firmware), keine Zeile.
            if (storage != null) ...[
              const SizedBox(height: Tokens.s),
              StorageRow(storage),
            ],
            if (current is! DemoTarget) ...[
              const SizedBox(height: Tokens.m),
              BigButton(
                label: l10n.connectionUseDemo,
                icon: Icons.science_outlined,
                kind: BigButtonKind.secondary,
                onPressed: _useDemo,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: Tokens.m),
              HintCard(
                icon: Icons.error_rounded,
                text: _error!,
                emphasized: true,
              ),
            ],
          ],
        ),
        secondary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.connectionFound, style: theme.textTheme.titleMedium),
            const SizedBox(height: Tokens.s),
            StreamBuilder(
              stream: _found,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text(
                    l10n.connectionDiscoveryFailed,
                    style: theme.textTheme.bodyLarge,
                  );
                }
                final bridges = snap.data ?? const <DiscoveredBridge>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final b in bridges)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Tokens.s),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.router_rounded, size: 32),
                            title: Text(b.name),
                            subtitle: Text(b.host),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              size: 32,
                            ),
                            onTap: () => unawaited(
                              _pair(
                                NetworkTarget(
                                  host: b.host,
                                  port: b.port,
                                  id: b.id,
                                  name: b.name,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (bridges.isEmpty)
                      Row(
                        children: [
                          const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                          const SizedBox(width: Tokens.m),
                          Expanded(
                            child: Text(
                              l10n.connectionSearching,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: Tokens.xl),
            Text(l10n.connectionManual, style: theme.textTheme.titleMedium),
            const SizedBox(height: Tokens.s),
            TextField(
              controller: _host,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.connectionHostLabel,
                hintText: '192.168.1.50',
              ),
            ),
            const SizedBox(height: Tokens.m),
            BigButton(
              label: l10n.connectionUse,
              icon: Icons.link_rounded,
              onPressed: () {
                final host = _host.text.trim();
                if (host.isNotEmpty) {
                  unawaited(_pair(NetworkTarget(host: host)));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Name, unter dem dieses Gerät bei der Brücke anfragt (wird auf dem
/// bestätigenden Handy angezeigt), z. B. „Google Pixel 8a“. Nur lokal ermittelt.
Future<String> deviceName() async {
  try {
    final info = DeviceInfoPlugin();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final a = await info.androidInfo;
        final maker = a.manufacturer.isEmpty
            ? ''
            : '${a.manufacturer[0].toUpperCase()}${a.manufacturer.substring(1)} ';
        return a.model.toLowerCase().startsWith(a.manufacturer.toLowerCase())
            ? a.model
            : '$maker${a.model}';
      case TargetPlatform.iOS:
        final i = await info.iosInfo;
        return i.modelName.isNotEmpty ? i.modelName : i.model;
      default:
        break;
    }
  } catch (_) {}
  return 'Rührlink-App';
}
