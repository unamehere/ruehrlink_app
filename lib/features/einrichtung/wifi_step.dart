import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_providers.dart';
import '../../core/provisioning/bridge_provisioning.dart';
import '../../core/provisioning/diag_log.dart';
import '../../l10n/l10n.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import '../../ui/widgets/hint_card.dart';
import 'bridge_step.dart' show setupErrorText;
import 'setup_controller.dart';
import 'setup_step_layout.dart';

/// Schritt 3: Heim-WLAN. Ist die Brücke schon im WLAN (`fk-info`), entfällt die
/// Auswahl. Sonst `fk-scan` → Netz wählen → Passwort → `fk-wifi`. Danach
/// `fk-token` und die Brücke im WLAN suchen – die App ist gekoppelt.
class WifiStep extends ConsumerStatefulWidget {
  const WifiStep({super.key});

  @override
  ConsumerState<WifiStep> createState() => _WifiStepState();
}

class _WifiStepState extends ConsumerState<WifiStep> {
  Future<List<WifiNetwork>>? _networks;
  final _password = TextEditingController();
  bool _loadingInfo = true;
  String? _alreadySsid;
  WifiNetwork? _selected;
  bool _obscure = true;
  bool _busy = false;
  bool _finishing = false;
  String? _error;
  String? _detail;

  BridgeProvisioning get _prov => ref.read(bridgeProvisioningProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _fail(Object e) {
    if (!mounted) return;
    final (msg, detail) = setupErrorText(context.l10n, e);
    setState(() {
      _error = msg;
      _detail = detail;
    });
  }

  Future<void> _load() async {
    try {
      final info = await _prov.info();
      if (!mounted) return;
      setState(() {
        _loadingInfo = false;
        if (info.homeConnected) {
          _alreadySsid = info.homeSsid;
        } else {
          _networks = _prov.scanWifi();
        }
      });
    } catch (e) {
      if (mounted) setState(() => _loadingInfo = false);
      _fail(e);
    }
  }

  Future<void> _join() async {
    final network = _selected!;
    setState(() {
      _busy = true;
      _error = null;
      _detail = null;
    });
    try {
      await _prov.joinWifi(network.ssid, _password.text);
      await _finish();
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Token holen, Ziel speichern, weiter zu „Maschine koppeln“.
  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _finishing = true;
      _error = null;
      _detail = null;
    });
    try {
      final target = await _prov.finish();
      await ref.read(bridgeTargetProvider.notifier).select(target);
      if (mounted) ref.read(setupStepProvider.notifier).next();
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _finishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final log = ref.watch(provisioningLogProvider);
    final selected = _selected;
    final already = _alreadySsid;

    final Widget body;
    if (_loadingInfo) {
      body = SetupProgress(l10n.setupBridgeConnecting('Freikoch'));
    } else if (already != null) {
      body = HintCard(
        icon: Icons.wifi_rounded,
        text: l10n.setupWifiAlready(already),
        emphasized: true,
      );
    } else if (selected == null) {
      body = _networkList();
    } else {
      body = _passwordForm();
    }

    final Widget? action = _loadingInfo
        ? null
        : already != null
        ? BigButton(
            label: _finishing ? l10n.setupFinishing : l10n.setupNext,
            icon: Icons.arrow_forward_rounded,
            busy: _busy,
            onPressed: _finish,
          )
        : selected == null
        ? null
        : BigButton(
            label: _finishing
                ? l10n.setupFinishing
                : (_busy ? l10n.setupWifiJoining : l10n.setupWifiJoin),
            icon: Icons.wifi_rounded,
            busy: _busy,
            onPressed: _join,
          );

    return SetupStepLayout(
      visual: const SetupIcon(Icons.wifi_rounded),
      title: l10n.setupWifiTitle,
      text: selected == null
          ? l10n.setupWifiText
          : l10n.setupWifiPasswordFor(selected.ssid),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body,
          if (_error != null) ...[
            const SizedBox(height: Tokens.m),
            SetupError(_error!, detail: _detail),
          ],
          const SizedBox(height: Tokens.m),
          DiagPanel(log: log),
        ],
      ),
      action: action,
    );
  }

  Widget _networkList() => FutureBuilder(
    future: _networks,
    builder: (context, snap) {
      final l10n = context.l10n;
      if (snap.connectionState != ConnectionState.done) {
        return SetupProgress(l10n.setupWifiSearching);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (snap.hasError) SetupError(l10n.setupConnectionLost),
          for (final n in snap.data ?? const <WifiNetwork>[])
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.s),
              child: Card(
                child: ListTile(
                  leading: Icon(_signalIcon(n.signal), size: 32),
                  title: Text(n.ssid),
                  trailing: n.secured ? const Icon(Icons.lock_rounded) : null,
                  onTap: () => setState(() => _selected = n),
                ),
              ),
            ),
          TextButton.icon(
            onPressed: () => setState(() => _networks = _prov.scanWifi()),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.setupWifiRescan),
          ),
        ],
      );
    },
  );

  Widget _passwordForm() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_selected!.secured)
          Text(l10n.setupWifiOpen, style: Theme.of(context).textTheme.bodyLarge)
        else
          TextField(
            controller: _password,
            enabled: !_busy,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            style: Theme.of(context).textTheme.titleLarge,
            decoration: InputDecoration(
              labelText: l10n.setupWifiPasswordLabel,
              suffixIcon: IconButton(
                tooltip: l10n.setupWifiShowPassword,
                icon: Icon(
                  _obscure
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _join(),
          ),
        const SizedBox(height: Tokens.s),
        TextButton.icon(
          onPressed: _busy ? null : () => setState(() => _selected = null),
          icon: const Icon(Icons.arrow_back_rounded),
          label: Text(l10n.setupWifiTitle),
        ),
      ],
    );
  }

  static IconData _signalIcon(int signal) => switch (signal) {
    >= 3 => Icons.network_wifi_rounded,
    2 => Icons.network_wifi_3_bar_rounded,
    1 => Icons.network_wifi_2_bar_rounded,
    _ => Icons.network_wifi_1_bar_rounded,
  };
}
