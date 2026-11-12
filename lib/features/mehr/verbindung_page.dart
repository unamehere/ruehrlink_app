import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/api/http_bridge_api.dart';
import '../../core/discovery/bridge_discovery.dart';
import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/layout.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import '../../ui/widgets/hint_card.dart';

/// Brücke wählen: Demo-Modus, im WLAN gefunden (mDNS) oder IP von Hand.
/// Bei einer echten Brücke folgt die Tasten-Kopplung aus api.md.
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

  /// Tasten-Kopplung: `POST /pair` wiederholen, bis die Taste gedrückt wurde.
  Future<void> _pair(NetworkTarget target) async {
    final l10n = context.l10n;
    setState(() {
      _pairing = target;
      _error = null;
    });
    final api = HttpBridgeApi(target);
    final deadline = DateTime.now().add(VerbindungPage.pairTimeout);
    String? error = l10n.connectionPairTimeout;
    try {
      while (mounted &&
          _pairing == target &&
          DateTime.now().isBefore(deadline)) {
        final token = await api.pair();
        if (token != null) {
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
        await Future<void>.delayed(VerbindungPage.pairInterval);
      }
    } on BridgeException {
      error = l10n.bridgeUnreachableHint;
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

    if (_pairing != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.connectionPairTitle)),
        body: AdaptivePage(
          primary: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HintCard(
                icon: Icons.touch_app_rounded,
                text: l10n.connectionPairTitle,
                detail: l10n.connectionPairText,
                emphasized: true,
              ),
              const SizedBox(height: Tokens.xl),
              const Center(child: CircularProgressIndicator()),
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
      appBar: AppBar(title: Text(l10n.connectionTitle)),
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
