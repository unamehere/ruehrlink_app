import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_providers.dart';
import '../../core/storage/app_storage.dart';
import '../../l10n/l10n.dart';
import '../../ui/hilfe_knopf.dart';
import '../hilfe/hilfe_themen.dart';
import '../../ui/theme.dart';
import 'scale_view.dart';

/// Einstellung: Waage automatisch zeigen, wenn der Kopf der Maschine hochgeklappt wird.
final scalePopupProvider = NotifierProvider<ScalePopupNotifier, bool>(
  ScalePopupNotifier.new,
);

class ScalePopupNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(appStorageProvider).scalePopup;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(appStorageProvider).setScalePopup(on);
  }
}

/// Waage als Fenster von unten. [closeWhenLidCloses]: schließt sich von selbst, sobald der Kopf
/// wieder zu ist (so beim automatischen Öffnen; von Hand geöffnet bleibt es offen).
Future<void> showScaleSheet(
  BuildContext context, {
  bool closeWhenLidCloses = false,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _ScaleSheet(closeWhenLidCloses: closeWhenLidCloses),
);

class _ScaleSheet extends ConsumerWidget {
  const _ScaleSheet({required this.closeWhenLidCloses});

  final bool closeWhenLidCloses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (closeWhenLidCloses) {
      ref.listen(applianceStatusProvider.select((s) => s.value?.lidClosed), (
        prev,
        next,
      ) {
        if (prev == false && next == true && context.mounted) {
          Navigator.of(context).maybePop();
        }
      });
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Tokens.l, 0, Tokens.l, Tokens.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UeberschriftMitHilfe(
              context.l10n.scaleTitle,
              hilfeWaage,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Tokens.l),
            const ScaleView(),
          ],
        ),
      ),
    );
  }
}

/// Öffnet die Waage, wenn der Kopf der Maschine hochgeklappt wird – nur im Koch-Tab
/// ([kochenTabIndex]), nur mit Waage und wenn in den Einstellungen nicht abgeschaltet.
class ScalePopupWatcher extends ConsumerStatefulWidget {
  const ScalePopupWatcher({
    super.key,
    required this.shell,
    required this.child,
  });

  static const kochenTabIndex = 0;

  final StatefulNavigationShell shell;
  final Widget child;

  @override
  ConsumerState<ScalePopupWatcher> createState() => _ScalePopupWatcherState();
}

class _ScalePopupWatcherState extends ConsumerState<ScalePopupWatcher> {
  bool _open = false;

  Future<void> _show() async {
    _open = true;
    await showScaleSheet(context, closeWhenLidCloses: true);
    _open = false;
  }

  bool get _hasScale =>
      ref.read(bridgeInfoProvider).value?.appliance?.caps?.hasScale ?? false;

  @override
  Widget build(BuildContext context) {
    ref.listen(applianceStatusProvider.select((s) => s.value), (prev, next) {
      final opened =
          prev != null &&
          next != null &&
          next.connected &&
          prev.lidClosed &&
          !next.lidClosed;
      if (!opened || _open || !mounted) return;
      if (widget.shell.currentIndex != ScalePopupWatcher.kochenTabIndex) return;
      if (!ref.read(scalePopupProvider) || !_hasScale) return;
      unawaited(_show());
    });
    return widget.child;
  }
}
