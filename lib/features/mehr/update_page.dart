import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/update/firmware.dart';
import '../../l10n/l10n.dart';
import '../../ui/layout.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import '../../ui/widgets/hint_card.dart';
import '../kochen/programs.dart';

enum _Phase { idle, uploading, restarting, done, failed }

/// Firmware der Brücke aktualisieren – mit der Firmware, die diese App mitbringt.
/// Ablauf: `freikoch_esp/docs/updates.md` (Upload, Neustart, Probebetrieb, ggf. Rollback).
class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({super.key});

  /// So lange darf die Brücke zum Neustart brauchen, bis sie wieder antwortet.
  static const restartTimeout = Duration(seconds: 90);

  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  String? _error;

  Future<void> _start(FirmwareManifest m) async {
    final l10n = context.l10n;
    final status = ref.read(applianceStatusProvider).value;
    final seq = ref.read(sequenceProvider).value;
    if ((status?.active ?? false) || (seq?.active ?? false)) {
      setState(() => _error = l10n.updateBusy);
      return;
    }
    setState(() {
      _phase = _Phase.uploading;
      _progress = 0;
      _error = null;
    });
    final api = ref.read(bridgeApiProvider);
    try {
      final image = await m.loadImage();
      await api.uploadFirmware(
        image,
        sha256: m.sha256,
        signature: m.sig,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
    } on BridgeException catch (e) {
      _fail(switch (e.code) {
        'busy' => l10n.updateBusy,
        'signature' || 'sha256' || 'image' || 'size' => l10n.updateRejected,
        _ when e.statusCode == 404 => l10n.updateNeedsUsb,
        _ => l10n.updateConnectionLost,
      });
      return;
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.restarting);
    await _waitForRestart(api, m.version);
  }

  /// Nach dem Neustart fragen, bis die Brücke wieder antwortet. Die erste Antwort
  /// bestätigt auf der Brücke zugleich die neue Firmware.
  Future<void> _waitForRestart(BridgeApi api, String expected) async {
    final l10n = context.l10n;
    await Future<void>.delayed(const Duration(seconds: 4));
    final deadline = DateTime.now().add(UpdatePage.restartTimeout);
    while (mounted && DateTime.now().isBefore(deadline)) {
      try {
        final info = await api.info();
        if (!mounted) return;
        api.reconnect();
        ref.invalidate(bridgeInfoProvider);
        if (compareVersions(info.fw, expected) == 0) {
          setState(() => _phase = _Phase.done);
        } else {
          _fail(l10n.updateRolledBack(info.fw));
        }
        return;
      } on BridgeException {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    _fail(l10n.updateNoAnswer);
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.failed;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final info = ref.watch(bridgeInfoProvider).value;
    final bundled = ref.watch(bundledFirmwareProvider).value;
    final check = ref.watch(firmwareCheckProvider);
    final busy = _phase == _Phase.uploading || _phase == _Phase.restarting;

    final List<Widget> body;
    switch (_phase) {
      case _Phase.uploading:
        body = [
          HintCard(
            icon: Icons.system_update_rounded,
            text: l10n.updateUploading,
            detail: l10n.updateKeepOpen,
            emphasized: true,
          ),
          const SizedBox(height: Tokens.l),
          LinearProgressIndicator(value: _progress, minHeight: 12),
          const SizedBox(height: Tokens.s),
          Text(
            '${(_progress * 100).round()} %',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ];
      case _Phase.restarting:
        body = [
          HintCard(
            icon: Icons.restart_alt_rounded,
            text: l10n.updateRestarting,
            detail: l10n.updateKeepOpen,
            emphasized: true,
          ),
          const SizedBox(height: Tokens.xl),
          const Center(child: CircularProgressIndicator()),
        ];
      case _Phase.done:
        body = [
          HintCard(
            icon: Icons.check_circle_rounded,
            text: l10n.updateDone(bundled?.version ?? ''),
            emphasized: true,
          ),
          const SizedBox(height: Tokens.l),
          BigButton(
            label: l10n.seqDismiss,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ];
      case _Phase.idle:
      case _Phase.failed:
        body = [
          _VersionRow(label: l10n.updateBridgeVersion, value: info?.fw ?? '–'),
          _VersionRow(
            label: l10n.updateAppVersion,
            value: bundled?.version ?? '–',
          ),
          const SizedBox(height: Tokens.l),
          if (_error != null) ...[
            HintCard(icon: Icons.error_outline_rounded, text: _error!),
            const SizedBox(height: Tokens.m),
          ],
          if (bundled == null)
            HintCard(
              icon: Icons.info_outline_rounded,
              text: l10n.updateNoFirmware,
            )
          else if (check == FirmwareCheck.bridgeNewer)
            HintCard(
              icon: Icons.info_outline_rounded,
              text: l10n.updateAppOlder,
              detail: l10n.updateAppOlderDetail,
            )
          else ...[
            if (check == FirmwareCheck.current)
              HintCard(icon: Icons.check_rounded, text: l10n.updateCurrent)
            else
              HintCard(
                icon: Icons.system_update_rounded,
                text: l10n.updateAvailable,
                detail: l10n.updateExplain,
                emphasized: true,
              ),
            const SizedBox(height: Tokens.l),
            BigButton(
              label: check == FirmwareCheck.current
                  ? l10n.updateReinstall
                  : l10n.updateStart,
              icon: Icons.system_update_rounded,
              kind: check == FirmwareCheck.current
                  ? BigButtonKind.secondary
                  : BigButtonKind.primary,
              onPressed: info == null ? null : () => _start(bundled),
            ),
          ],
        ];
    }

    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.updateTitle),
          automaticallyImplyLeading: !busy,
        ),
        body: AdaptivePage(
          primary: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: body,
          ),
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.s / 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
