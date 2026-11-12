import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/provisioning/bridge_provisioning.dart';
import '../../l10n/l10n.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import 'setup_controller.dart';
import 'setup_step_layout.dart';

/// Schritt 2: Brücke per Bluetooth finden, Code vom Etikett eingeben/scannen.
class BridgeStep extends ConsumerStatefulWidget {
  const BridgeStep({super.key});

  @override
  ConsumerState<BridgeStep> createState() => _BridgeStepState();
}

class _BridgeStepState extends ConsumerState<BridgeStep> {
  late final Stream<List<ProvisionableBridge>> _scan = ref
      .read(bridgeProvisioningProvider)
      .scan();
  final _pin = TextEditingController();
  ProvisionableBridge? _selected;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(bridgeProvisioningProvider)
          .connect(_selected!, pin: _pin.text);
      ref.read(setupStepProvider.notifier).next();
    } on ProvisioningException catch (e) {
      setState(
        () => _error = e.error == ProvisioningError.wrongPin
            ? l10n.setupWrongPin
            : l10n.setupConnectionLost,
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
      visual: const SetupIcon(Icons.bluetooth_searching_rounded),
      title: selected == null ? l10n.setupBridgeTitle : l10n.setupPinTitle,
      text: selected == null ? l10n.setupBridgeText : l10n.setupPinText,
      content: selected == null ? _bridgeList() : _pinForm(),
      action: selected == null
          ? null
          : BigButton(
              label: l10n.setupConnect,
              icon: Icons.link_rounded,
              busy: _busy,
              onPressed: _connect,
            ),
    );
  }

  Widget _bridgeList() => StreamBuilder(
    stream: _scan,
    builder: (context, snap) {
      final bridges = snap.data ?? const [];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in bridges)
            Card(
              child: ListTile(
                leading: const Icon(Icons.router_rounded, size: 36),
                title: Text(b.name),
                trailing: const Icon(Icons.chevron_right_rounded, size: 32),
                onTap: () => setState(() => _selected = b),
              ),
            ),
          if (snap.connectionState != ConnectionState.done)
            SetupProgress(context.l10n.setupBridgeSearching),
        ],
      );
    },
  );

  Widget _pinForm() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BigButton(
          label: l10n.setupScanQr,
          icon: Icons.qr_code_scanner_rounded,
          kind: BigButtonKind.secondary,
          // QR-Scanner folgt mit der echten BLE-Anbindung.
          onPressed: () =>
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l10n.setupScanQrSoon))),
        ),
        const SizedBox(height: Tokens.l),
        TextField(
          controller: _pin,
          enabled: !_busy,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          style: Theme.of(context).textTheme.headlineSmall,
          decoration: InputDecoration(labelText: l10n.setupPinLabel),
          onSubmitted: (_) => _connect(),
        ),
        if (_error != null) ...[
          const SizedBox(height: Tokens.m),
          SetupError(_error!),
        ],
      ],
    );
  }
}
