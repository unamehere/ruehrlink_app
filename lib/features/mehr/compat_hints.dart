import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_providers.dart';
import '../../core/models/models.dart';
import '../../core/storage/app_storage.dart';
import '../../core/update/firmware.dart';
import '../../l10n/l10n.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/hint_card.dart';

/// API passt nicht: welche Seite aktualisiert werden muss. Steuern ist dann gesperrt
/// (siehe [BridgeInfo.readyCaps]), der Status bleibt sichtbar.
class CompatHint extends StatelessWidget {
  const CompatHint({super.key, required this.compat});

  final BridgeCompat compat;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bridgeOld = compat == BridgeCompat.bridgeTooOld;
    return HintCard(
      icon: bridgeOld
          ? Icons.system_update_rounded
          : Icons.info_outline_rounded,
      text: bridgeOld ? l10n.compatBridgeTooOld : l10n.updateAppOlder,
      detail: bridgeOld
          ? l10n.compatBridgeTooOldDetail
          : l10n.compatAppTooOldDetail,
      emphasized: true,
    );
  }
}

/// Fähigkeiten, nach denen die App Funktionen freischaltet, mit Namen für den Hinweis.
Map<String, String> _usedFeatures(AppLocalizations l10n) => {
  'sequence': l10n.featureSequence,
  'scale': l10n.featureScale,
  'scale.tare': l10n.featureTare,
  'ota': l10n.featureOta,
};

/// Hinweise zum Rührlink oben im Kochen-Tab, höchstens einer auf einmal:
/// 1. API passt nicht → [CompatHint] (bleibt, solange es so ist),
/// 2. eingebaute Firmware neuer → dezenter Update-Hinweis,
/// 3. Fähigkeit fehlt → einmal pro Firmware-Version „Dafür braucht dein Rührlink ein Update“.
class BridgeHints extends ConsumerStatefulWidget {
  const BridgeHints({super.key});

  @override
  ConsumerState<BridgeHints> createState() => _BridgeHintsState();
}

class _BridgeHintsState extends ConsumerState<BridgeHints> {
  /// Für diese Firmware schon gezeigt (in dieser Sitzung noch sichtbar, bis geschlossen).
  String? _shownFor;
  bool _closed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final info = ref.watch(bridgeInfoProvider).value;
    if (info == null) return const SizedBox.shrink();
    Widget pad(Widget w) => Padding(
      padding: const EdgeInsets.only(bottom: Tokens.m),
      child: w,
    );

    if (info.compat != BridgeCompat.ok) {
      return pad(
        GestureDetector(
          onTap: info.compat == BridgeCompat.bridgeTooOld
              ? () => context.go('/mehr/update')
              : null,
          child: CompatHint(compat: info.compat),
        ),
      );
    }

    if (ref.watch(bundledUpdateProvider) != null) {
      return pad(
        GestureDetector(
          onTap: () => context.go('/mehr/update'),
          child: HintCard(
            icon: Icons.system_update_rounded,
            text: l10n.updateAvailable,
            detail: l10n.updateTapHint,
          ),
        ),
      );
    }

    final missing = [
      for (final e in _usedFeatures(l10n).entries)
        if (!info.has(e.key)) e.value,
    ];
    if (missing.isEmpty || _closed) return const SizedBox.shrink();
    final storage = ref.read(appStorageProvider);
    if (_shownFor != info.fw) {
      if (storage.featureHintFw == info.fw) return const SizedBox.shrink();
      // Einmal pro Firmware-Version: gleich als gesehen merken, kein Dauerbanner.
      _shownFor = info.fw;
      unawaited(storage.setFeatureHintFw(info.fw));
    }
    return pad(
      Stack(
        children: [
          GestureDetector(
            onTap: () => context.go('/mehr/update'),
            child: HintCard(
              icon: Icons.info_outline_rounded,
              text: l10n.featureMissing,
              detail: l10n.featureMissingDetail(missing.join(', ')),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => setState(() => _closed = true),
            ),
          ),
        ],
      ),
    );
  }
}
