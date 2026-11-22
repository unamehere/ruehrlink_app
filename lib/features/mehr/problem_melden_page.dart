import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/event_log.dart';
import '../../core/models/models.dart';
import '../../core/support.dart';
import '../../l10n/l10n.dart';
import '../../ui/layout.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import '../../version.dart';
import 'problem_report.dart';

/// Mehr → „Problem melden“: Freitext, optional ein Bild, Diagnose zum Ansehen, Versand über das
/// Teilen-Menü oder `mailto:`. Die App selbst schickt nichts ins Internet.
class ProblemMeldenPage extends ConsumerStatefulWidget {
  const ProblemMeldenPage({super.key});

  @override
  ConsumerState<ProblemMeldenPage> createState() => _ProblemMeldenPageState();
}

/// Was beim Öffnen eingesammelt wurde (ohne die Beschreibung, die ändert sich beim Tippen).
class _Diagnose {
  const _Diagnose({
    required this.createdAt,
    required this.device,
    required this.target,
    this.info,
    this.infoError,
    this.status,
    this.statusError,
    this.diag,
    this.diagNote,
  });

  final DateTime createdAt;
  final String device;
  final BridgeTarget target;
  final BridgeInfo? info;
  final String? infoError;
  final ApplianceStatus? status;
  final String? statusError;
  final Json? diag;
  final String? diagNote;
}

class _ProblemMeldenPageState extends ConsumerState<ProblemMeldenPage> {
  final _text = TextEditingController();
  XFile? _image;
  _Diagnose? _diagnose;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _collect());
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  static String _errorText(BridgeException e) =>
      [e.kind.name, ?e.statusCode?.toString(), ?e.code].join(' ');

  Future<void> _collect() async {
    final l10n = context.l10n;
    setState(() => _diagnose = null);
    final api = ref.read(bridgeApiProvider);
    final target = ref.read(bridgeTargetProvider);
    BridgeInfo? info;
    ApplianceStatus? status;
    Json? diag;
    String? infoError, statusError, diagNote;
    try {
      info = await api.info();
    } on BridgeException catch (e) {
      infoError = _errorText(e);
    }
    try {
      status = await api.state();
    } on BridgeException catch (e) {
      statusError = _errorText(e);
    }
    if (target is DemoTarget) {
      diagNote = l10n.problemBoxLogDemo;
    } else if (info == null) {
      diagNote = l10n.problemBoxLogUnreachable;
    } else if (!info.has('diag')) {
      diagNote = l10n.problemBoxLogOld;
    } else {
      try {
        diag = await api.diag();
      } on BridgeException catch (e) {
        diagNote = '${l10n.problemBoxLogUnreachable} (${_errorText(e)})';
      }
    }
    final device = await _deviceDescription().timeout(
      const Duration(seconds: 3),
      onTimeout: () => defaultTargetPlatform.name,
    );
    if (!mounted) return;
    setState(
      () => _diagnose = _Diagnose(
        createdAt: DateTime.now(),
        device: device,
        target: target,
        info: info,
        infoError: infoError,
        status: status,
        statusError: statusError,
        diag: diag,
        diagNote: diagNote,
      ),
    );
  }

  ProblemReport? get _report {
    final d = _diagnose;
    if (d == null) return null;
    return ProblemReport(
      createdAt: d.createdAt,
      description: _text.text,
      appVersion: appVersion,
      device: d.device,
      target: d.target,
      info: d.info,
      infoError: d.infoError,
      status: d.status,
      statusError: d.statusError,
      diag: d.diag,
      diagNote: d.diagNote,
      events: appEvents.lines(),
      droppedEvents: appEvents.dropped,
      screenshot: _image != null,
    );
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file != null && mounted) setState(() => _image = file);
  }

  Future<void> _share(ProblemReport report) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${report.fileName}');
      await file.writeAsString(report.toText());
      final description = _text.text.trim();
      await SharePlus.instance.share(
        ShareParams(
          subject: report.subject,
          text: [
            l10n.problemRecipient(kProblemReportEmail),
            if (description.isNotEmpty) description,
          ].join('\n\n'),
          files: [
            XFile(file.path, mimeType: 'text/plain'),
            if (_image case final img?) XFile(img.path),
          ],
        ),
      );
      appEvents.add('bericht', 'Bericht über Teilen geöffnet');
    } catch (e) {
      appEvents.add('bericht', 'Teilen fehlgeschlagen: ${e.runtimeType}');
      messenger.showSnackBar(SnackBar(content: Text(l10n.problemShareFailed)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _mail(ProblemReport report) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final body = report.mailBody(hint: l10n.problemMailTruncated);
    // Leerzeichen als %20 (nicht „+“ wie bei queryParameters) – sonst zeigen manche Mail-Apps „+“.
    final uri = Uri.parse(
      'mailto:$kProblemReportEmail'
      '?subject=${Uri.encodeComponent(report.subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );
    var ok = false;
    try {
      ok = await launchUrl(uri);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.problemMailFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final report = _report;
    final diagNote = _diagnose?.diagNote;
    final busy = report == null || _sending;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.problemTitle)),
      body: AdaptivePage(
        primary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.problemIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: Tokens.m),
            TextField(
              controller: _text,
              minLines: 4,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.problemDescriptionLabel,
                hintText: l10n.problemDescriptionHint,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Tokens.m),
            if (_image case final img?)
              Card(
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    Image.file(
                      File(img.path),
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(width: Tokens.m),
                    Expanded(
                      child: Text(img.name, overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      tooltip: l10n.problemRemoveImage,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _image = null),
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(l10n.problemAttachImage),
              ),
            const SizedBox(height: Tokens.m),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: Text(l10n.problemIncluded),
                subtitle: Text(
                  report == null
                      ? l10n.problemCollecting
                      : diagNote ?? l10n.problemIncludedHint,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  Tokens.m,
                  0,
                  Tokens.m,
                  Tokens.m,
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (report == null)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    if (diagNote != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Tokens.s),
                        child: Text(l10n.problemIncludedHint),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _collect,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(l10n.problemReload),
                      ),
                    ),
                    SelectableText(
                      report.toText(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Tokens.l),
            BigButton(
              label: l10n.problemShare,
              icon: Icons.share_rounded,
              busy: busy,
              onPressed: report == null ? null : () => _share(report),
            ),
            const SizedBox(height: Tokens.s),
            BigButton(
              label: l10n.problemMail,
              icon: Icons.mail_outline_rounded,
              kind: BigButtonKind.secondary,
              onPressed: report == null || _sending
                  ? null
                  : () => _mail(report),
            ),
            const SizedBox(height: Tokens.s),
            Text(
              '${l10n.problemRecipient(kProblemReportEmail)} '
              '${l10n.problemMailHint}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Handy und Betriebssystem, z. B. „Google Pixel 8a, Android 15 (SDK 35)“. Nur lokal ermittelt.
Future<String> _deviceDescription() async {
  try {
    final info = DeviceInfoPlugin();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final a = await info.androidInfo;
        return '${a.manufacturer} ${a.model}, Android ${a.version.release} '
            '(SDK ${a.version.sdkInt})';
      case TargetPlatform.iOS:
        final i = await info.iosInfo;
        return '${i.modelName.isNotEmpty ? i.modelName : i.model}, '
            '${i.systemName} ${i.systemVersion}';
      default:
        return defaultTargetPlatform.name;
    }
  } catch (_) {
    return defaultTargetPlatform.name;
  }
}
