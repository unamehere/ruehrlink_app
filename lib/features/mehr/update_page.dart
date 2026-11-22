import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/event_log.dart';
import '../../core/models/models.dart';
import '../../core/update/firmware.dart';
import '../../l10n/l10n.dart';
import '../../ui/hilfe_knopf.dart';
import '../../ui/layout.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import '../../ui/widgets/hint_card.dart';
import '../hilfe/hilfe_themen.dart';
import '../kochen/programs.dart';
import 'compat_hints.dart';

/// Releases der Firmware – öffnet der Browser, die App selbst fragt nirgends nach Updates.
final firmwareReleasesUrl = Uri.parse(
  'https://github.com/unamehere/ruehrlink_esp/releases',
);

enum _Phase { idle, checking, uploading, restarting, done, failed }

/// Firmware des Rührlink aktualisieren – mit einer Update-Datei `.rlfw`, die der Nutzer selbst
/// heruntergeladen hat, oder mit der Firmware, die diese App mitbringt.
/// Ablauf: `ruehrlink_esp/docs/updates.md` (lokal prüfen, Upload, Neustart, Probebetrieb, ggf. Rollback).
class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({super.key});

  /// So lange darf der Rührlink zum Neustart brauchen, bis er wieder antwortet.
  static const restartTimeout = Duration(seconds: 90);

  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  String? _error;

  /// Geprüfte Datei, die auf Bestätigung wartet.
  FirmwarePackage? _selected;

  bool get _machineBusy {
    final status = ref.read(applianceStatusProvider).value;
    final seq = ref.read(sequenceProvider).value;
    return (status?.active ?? false) || (seq?.active ?? false);
  }

  Future<void> _pickFile() async {
    final file = await openFile();
    if (file == null || !mounted) return;
    await _check(file.readAsBytes);
  }

  Future<void> _useBundled(BundledFirmware b) => _check(b.bytes);

  Future<void> _check(Future<Uint8List> Function() read) async {
    final l10n = context.l10n;
    setState(() {
      _phase = _Phase.checking;
      _error = null;
      _selected = null;
    });
    try {
      final pkg = await FirmwarePackage.open(await read());
      appEvents.add(
        'update',
        'Datei geprüft: Firmware ${pkg.manifest.version}',
      );
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _selected = pkg;
      });
    } on FirmwareFileException catch (e) {
      appEvents.add('update', 'Datei abgelehnt: ${e.error.name}');
      _fail(switch (e.error) {
        FirmwareFileError.invalid => l10n.updateFileInvalid,
        FirmwareFileError.damaged => l10n.updateFileDamaged,
        FirmwareFileError.signature => l10n.updateFileSignature,
        FirmwareFileError.appTooOld => l10n.updateFileAppTooOld,
      });
    } on Exception {
      _fail(l10n.updateFileInvalid);
    }
  }

  Future<void> _install(FirmwarePackage pkg, String current) async {
    final l10n = context.l10n;
    if (_machineBusy) {
      setState(() => _error = l10n.updateBusy);
      return;
    }
    final v = pkg.manifest.version;
    if (current.isNotEmpty && compareVersions(v, current) < 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.updateDowngradeTitle),
          content: Text(l10n.updateDowngradeText(current, v)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.updateDowngradeConfirm),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      _phase = _Phase.uploading;
      _progress = 0;
      _error = null;
    });
    final api = ref.read(bridgeApiProvider);
    appEvents.add('update', 'Upload $current → $v');
    try {
      await api.uploadFirmware(
        pkg.image,
        sha256: pkg.manifest.sha256,
        signature: pkg.manifest.sig,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
    } on BridgeException catch (e) {
      appEvents.add(
        'update',
        'Upload fehlgeschlagen: ${e.code ?? e.kind.name}',
      );
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
    await _waitForRestart(api, v);
  }

  /// Nach dem Neustart fragen, bis der Rührlink wieder antwortet. Die erste Antwort
  /// bestätigt dort zugleich die neue Firmware.
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
        appEvents.add('update', 'Neustart fertig, läuft ${info.fw}');
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
    appEvents.add('update', 'Keine Antwort nach dem Neustart');
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
    final bundledUpdate = ref.watch(bundledUpdateProvider);
    final machineBusy =
        (ref.watch(applianceStatusProvider).value?.active ?? false) ||
        (ref.watch(sequenceProvider).value?.active ?? false);
    final busy = _phase == _Phase.uploading || _phase == _Phase.restarting;
    final current = info?.fw ?? '';

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
            text: l10n.updateDone(_selected?.manifest.version ?? ''),
            emphasized: true,
          ),
          const SizedBox(height: Tokens.l),
          BigButton(
            label: l10n.seqDismiss,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ];
      case _Phase.checking:
        body = [
          HintCard(icon: Icons.fact_check_outlined, text: l10n.updateChecking),
          const SizedBox(height: Tokens.xl),
          const Center(child: CircularProgressIndicator()),
        ];
      case _Phase.idle:
      case _Phase.failed:
        final selected = _selected;
        final canOta = info == null || info.has('ota');
        body = [
          _VersionRow(
            label: l10n.updateBridgeVersion,
            value: current.isEmpty ? '–' : current,
          ),
          if (bundled != null)
            _VersionRow(
              label: l10n.updateAppVersion,
              value: bundled.manifest.version,
            ),
          const SizedBox(height: Tokens.l),
          if (info != null && info.compat != BridgeCompat.ok) ...[
            CompatHint(compat: info.compat),
            const SizedBox(height: Tokens.m),
          ],
          if (_error != null) ...[
            HintCard(icon: Icons.error_outline_rounded, text: _error!),
            const SizedBox(height: Tokens.m),
          ],
          if (!canOta)
            HintCard(icon: Icons.usb_rounded, text: l10n.updateNeedsUsb)
          else if (machineBusy)
            HintCard(icon: Icons.info_outline_rounded, text: l10n.updateBusy)
          else if (selected != null) ...[
            _PackageCard(pkg: selected, current: current),
            const SizedBox(height: Tokens.l),
            if (compareVersions(selected.manifest.version, current) != 0 ||
                current.isEmpty)
              BigButton(
                label: l10n.updateStart,
                icon: Icons.system_update_rounded,
                kind: compareVersions(selected.manifest.version, current) < 0
                    ? BigButtonKind.secondary
                    : BigButtonKind.primary,
                onPressed: info == null
                    ? null
                    : () => _install(selected, current),
              ),
            const SizedBox(height: Tokens.s),
            BigButton(
              label: l10n.updateOtherFile,
              icon: Icons.folder_open_rounded,
              kind: BigButtonKind.secondary,
              onPressed: _pickFile,
            ),
          ] else ...[
            if (bundledUpdate != null && bundled != null) ...[
              HintCard(
                icon: Icons.system_update_rounded,
                text: l10n.updateAvailable,
                detail: l10n.updateExplain,
              ),
              const SizedBox(height: Tokens.m),
              BigButton(
                label: l10n.updateInstallBundled(bundledUpdate.version),
                icon: Icons.system_update_rounded,
                onPressed: () => _useBundled(bundled),
              ),
              const SizedBox(height: Tokens.s),
            ],
            BigButton(
              label: l10n.updatePickFile,
              icon: Icons.folder_open_rounded,
              kind: bundledUpdate != null
                  ? BigButtonKind.secondary
                  : BigButtonKind.primary,
              onPressed: _pickFile,
            ),
            const SizedBox(height: Tokens.s),
            Text(
              l10n.updatePickFileHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: Tokens.m),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(l10n.updateGithubLink),
              onPressed: () => unawaited(
                launchUrl(
                  firmwareReleasesUrl,
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
          ),
        ];
    }

    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.updateTitle),
          automaticallyImplyLeading: !busy,
          actions: const [HilfeKnopf(hilfeUpdate)],
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

/// Geprüfte Update-Datei: Version, Kanal, Sicherheitsupdate, Notizen, ggf. Downgrade-Warnung.
class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.pkg, required this.current});

  final FirmwarePackage pkg;
  final String current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final m = pkg.manifest;
    final cmp = current.isEmpty ? 1 : compareVersions(m.version, current);
    final fg = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.updateFileVersion(m.version),
              style: theme.textTheme.titleLarge,
            ),
            if (m.security)
              _Line(
                Icons.shield_outlined,
                l10n.updateSecurity,
                emphasized: true,
              ),
            if (m.channel == 'beta')
              _Line(Icons.science_outlined, l10n.updateBeta),
            if (cmp == 0) _Line(Icons.check_rounded, l10n.updateSameVersion),
            if (cmp < 0)
              _Line(
                Icons.history_rounded,
                l10n.updateDowngrade(current),
                emphasized: true,
              ),
            if (m.notes.isNotEmpty) ...[
              const SizedBox(height: Tokens.s),
              Text(
                m.notes,
                style: theme.textTheme.bodyLarge?.copyWith(color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text, {this.emphasized = false});

  final IconData icon;
  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = emphasized
        ? theme.colorScheme.tertiary
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.s / 2),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: Tokens.s),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
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
