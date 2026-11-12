import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/provisioning/bridge_provisioning.dart';
import '../../core/provisioning/diag_log.dart';
import '../../l10n/l10n.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import '../../ui/widgets/hint_card.dart';
import 'qr_scan_page.dart';
import 'setup_controller.dart';
import 'setup_step_layout.dart';

/// Schritt 2: Code vom Etikett (QR scannen oder abtippen) → Brücke per
/// Bluetooth finden → verschlüsselte Sitzung (Security 2).
class BridgeStep extends ConsumerStatefulWidget {
  const BridgeStep({super.key});

  /// So lange wird gesucht, bevor „Keine Brücke gefunden“ erscheint.
  static const searchTimeout = Duration(seconds: 20);

  @override
  ConsumerState<BridgeStep> createState() => _BridgeStepState();
}

enum _Phase { code, searching, connecting }

class _BridgeStepState extends ConsumerState<BridgeStep> {
  final _codeField = TextEditingController();
  _Phase _phase = _Phase.code;
  SetupCode? _code;
  List<ProvisionableBridge> _found = const [];
  ProvisionableBridge? _connectingTo;
  StreamSubscription<List<ProvisionableBridge>>? _scan;
  Timer? _timeout;
  String? _error;
  String? _detail;

  BridgeProvisioning get _prov => ref.read(bridgeProvisioningProvider);
  DiagLog get _log => ref.read(provisioningLogProvider);

  @override
  void dispose() {
    _stopSearch();
    _codeField.dispose();
    super.dispose();
  }

  void _stopSearch() {
    unawaited(_scan?.cancel());
    _scan = null;
    _timeout?.cancel();
  }

  void _fail(String message, [String? detail]) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _detail = detail;
    });
  }

  Future<void> _scanQr() async {
    final raw = await QrScanPage.open(context);
    if (raw != null && mounted) _useCode(raw);
  }

  void _useCode(String raw) {
    final code = SetupCode.parse(raw);
    if (code == null) {
      _fail(context.l10n.setupCodeInvalid);
      return;
    }
    _log.add('Code: ${code.name ?? 'abgetippt'} (${code.pop.length} Zeichen)');
    _code = code;
    _startSearch();
  }

  void _startSearch() {
    final l10n = context.l10n;
    _stopSearch();
    setState(() {
      _phase = _Phase.searching;
      _found = const [];
      _error = null;
      _detail = null;
    });
    _scan = _prov.scan().listen(
      (list) {
        if (!mounted) return;
        setState(() => _found = list);
        final name = _code?.name;
        if (name == null) return;
        for (final b in list) {
          if (b.name.toLowerCase() == name.toLowerCase()) {
            unawaited(_connect(b));
            return;
          }
        }
      },
      onError: (Object e) {
        _stopSearch();
        final (msg, detail) = setupErrorText(l10n, e);
        _fail(msg, detail);
      },
    );
    _timeout = Timer(BridgeStep.searchTimeout, () {
      if (_phase == _Phase.searching && _found.isEmpty) {
        _stopSearch();
        _log.add('Keine Brücke nach ${BridgeStep.searchTimeout.inSeconds} s');
        _fail(l10n.setupBridgeNotFound);
      }
    });
  }

  Future<void> _connect(ProvisionableBridge bridge) async {
    final l10n = context.l10n;
    final code = _code;
    if (code == null || _phase == _Phase.connecting) return;
    _stopSearch();
    setState(() {
      _phase = _Phase.connecting;
      _connectingTo = bridge;
      _error = null;
      _detail = null;
    });
    try {
      await _prov.connect(bridge, code: code);
      if (mounted) ref.read(setupStepProvider.notifier).next();
    } catch (e) {
      final (msg, detail) = setupErrorText(l10n, e);
      if (!mounted) return;
      setState(() {
        // Falscher Code: zurück zur Eingabe, sonst bei der Suche bleiben.
        _phase =
            e is ProvisioningException && e.error == ProvisioningError.wrongPin
            ? _Phase.code
            : _Phase.searching;
        _error = msg;
        _detail = detail;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final log = ref.watch(provisioningLogProvider);
    final errorBox = _error == null
        ? null
        : SetupError(_error!, detail: _detail);

    if (_phase == _Phase.code) {
      return SetupStepLayout(
        visual: const SetupIcon(Icons.qr_code_2_rounded),
        title: l10n.setupPinTitle,
        text: l10n.setupPinText,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BigButton(
              label: l10n.setupScanQr,
              icon: Icons.qr_code_scanner_rounded,
              onPressed: _scanQr,
            ),
            const SizedBox(height: Tokens.s),
            Text(
              l10n.setupScanQrHint,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Tokens.l),
            TextField(
              controller: _codeField,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              style: Theme.of(context).textTheme.headlineSmall,
              decoration: InputDecoration(labelText: l10n.setupPinLabel),
              onSubmitted: _useCode,
            ),
            if (errorBox != null) ...[
              const SizedBox(height: Tokens.m),
              errorBox,
            ],
            const SizedBox(height: Tokens.m),
            DiagPanel(log: log),
          ],
        ),
        action: BigButton(
          label: l10n.setupNext,
          icon: Icons.arrow_forward_rounded,
          kind: BigButtonKind.secondary,
          onPressed: () => _useCode(_codeField.text),
        ),
      );
    }

    final searching = _phase == _Phase.searching && _error == null;
    final choose = _code?.name == null && _phase == _Phase.searching;
    return SetupStepLayout(
      visual: const SetupIcon(Icons.bluetooth_searching_rounded),
      title: l10n.setupBridgeTitle,
      text: l10n.setupBridgeText,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HintCard(
            icon: Icons.bluetooth_rounded,
            text: l10n.setupBluetoothHint,
          ),
          if (_phase == _Phase.connecting)
            SetupProgress(l10n.setupBridgeConnecting(_connectingTo!.name))
          else if (searching)
            SetupProgress(l10n.setupBridgeSearching),
          if (choose && _found.isNotEmpty) ...[
            const SizedBox(height: Tokens.s),
            Text(
              l10n.setupBridgeChoose,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: Tokens.s),
            for (final b in _found)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.s),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.router_rounded, size: 36),
                    title: Text(b.name),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 32),
                    onTap: () => _connect(b),
                  ),
                ),
              ),
          ],
          if (errorBox != null) ...[
            const SizedBox(height: Tokens.m),
            errorBox,
            const SizedBox(height: Tokens.m),
            BigButton(
              label: l10n.retry,
              icon: Icons.refresh_rounded,
              kind: BigButtonKind.secondary,
              onPressed: _startSearch,
            ),
          ],
          const SizedBox(height: Tokens.m),
          DiagPanel(log: log),
        ],
      ),
      action: TextButton(
        onPressed: _phase == _Phase.connecting
            ? null
            : () {
                _stopSearch();
                setState(() {
                  _phase = _Phase.code;
                  _error = null;
                  _detail = null;
                });
              },
        child: Text(l10n.setupChangeCode),
      ),
    );
  }
}

/// Verständlicher Text (+ technische Einzelheit) für Fehler der Einrichtung.
(String, String?) setupErrorText(AppLocalizations l10n, Object error) {
  if (error is! ProvisioningException) {
    return (l10n.setupConnectionLost, '$error');
  }
  final text = switch (error.error) {
    ProvisioningError.bluetoothOff => l10n.setupBluetoothOff,
    ProvisioningError.permissionDenied => l10n.setupPermissionDenied,
    ProvisioningError.notFound => l10n.setupBridgeNotFound,
    ProvisioningError.wrongPin => l10n.setupWrongPin,
    ProvisioningError.wrongPassword => l10n.setupWifiWrongPassword,
    ProvisioningError.wifiNotFound => l10n.setupWifiNotFound,
    ProvisioningError.wifiFailed => l10n.setupWifiFailed,
    ProvisioningError.connectionLost => l10n.setupConnectionLost,
  };
  return (
    text,
    '${error.error.name}${error.detail == null ? '' : ': ${error.detail}'}',
  );
}
