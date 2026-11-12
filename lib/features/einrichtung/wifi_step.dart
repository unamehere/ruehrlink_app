import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_providers.dart';
import '../../core/provisioning/bridge_provisioning.dart';
import '../../l10n/l10n.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import 'setup_controller.dart';
import 'setup_step_layout.dart';

/// Schritt 3: Heim-WLAN wählen und Passwort eingeben. Danach ist die Brücke
/// im WLAN und die App kennt Adresse und Token.
class WifiStep extends ConsumerStatefulWidget {
  const WifiStep({super.key});

  @override
  ConsumerState<WifiStep> createState() => _WifiStepState();
}

class _WifiStepState extends ConsumerState<WifiStep> {
  late Future<List<WifiNetwork>> _networks = _scan();
  final _password = TextEditingController();
  WifiNetwork? _selected;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  Future<List<WifiNetwork>> _scan() =>
      ref.read(bridgeProvisioningProvider).scanWifi();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final l10n = context.l10n;
    final provisioning = ref.read(bridgeProvisioningProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await provisioning.joinWifi(_selected!.ssid, _password.text);
      final target = await provisioning.finish();
      await provisioning.disconnect();
      await ref.read(bridgeTargetProvider.notifier).select(target);
      ref.read(setupStepProvider.notifier).next();
    } on ProvisioningException catch (e) {
      setState(
        () => _error = switch (e.error) {
          ProvisioningError.wrongPassword => l10n.setupWifiWrongPassword,
          ProvisioningError.wifiNotFound => l10n.setupWifiNotFound,
          _ => l10n.setupConnectionLost,
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = _selected;
    return SetupStepLayout(
      visual: const SetupIcon(Icons.wifi_rounded),
      title: l10n.setupWifiTitle,
      text: selected == null
          ? l10n.setupWifiText
          : l10n.setupWifiPasswordFor(selected.ssid),
      content: selected == null ? _networkList() : _passwordForm(),
      action: selected == null
          ? null
          : BigButton(
              label: _busy ? l10n.setupWifiJoining : l10n.setupWifiJoin,
              icon: Icons.wifi_rounded,
              busy: _busy,
              onPressed: _join,
            ),
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
            onPressed: () => setState(() => _networks = _scan()),
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
        if (_error != null) ...[
          const SizedBox(height: Tokens.m),
          SetupError(_error!),
        ],
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
