import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../l10n/l10n.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/big_button.dart';
import 'scale.dart';

/// Waage mit großer Zahl und Tara-Knopf. Mit [target] als Einwiege-Hilfe: Ring füllt sich,
/// grau → bernstein (fast) → grün (passt) → rot (zu viel), kurze Vibration beim Erreichen.
///
/// Einsetzbar im Kochmodus (Schritt mit `weigh`), im Waage-Fenster des Koch-Tabs usw.
class ScaleView extends ConsumerStatefulWidget {
  const ScaleView({super.key, this.target, this.ingredient, this.size = 240});

  /// Zielmenge in Gramm (`null` = einfach wiegen).
  final double? target;

  /// Was eingewogen wird, z. B. „Dinkelmehl 630“ (optional, über der Zahl).
  final String? ingredient;

  /// Durchmesser des Rings.
  final double size;

  @override
  ConsumerState<ScaleView> createState() => _ScaleViewState();
}

class _ScaleViewState extends ConsumerState<ScaleView> {
  late final Timer _tick;
  bool _taring = false;
  ScaleZone? _lastZone;

  @override
  void initState() {
    super.initState();
    // Neu zeichnen, damit „verbindet …“ erscheint, wenn keine Werte mehr kommen.
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  Future<void> _tare() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _taring = true);
    try {
      await ref.read(bridgeApiProvider).tareScale();
      unawaited(HapticFeedback.selectionClick());
    } on BridgeException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.scaleTareFailed)));
    } finally {
      if (mounted) setState(() => _taring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reading = ref.watch(scaleProvider).value;
    final connected =
        ref.watch(applianceStatusProvider).value?.connected ?? false;
    final live =
        reading != null &&
        DateTime.now().difference(reading.at) < scaleStaleAfter;
    final net = live ? reading.net : null;
    final target = widget.target;

    final zone = net != null && target != null ? scaleZone(net, target) : null;
    if (zone == ScaleZone.onTarget && _lastZone != ScaleZone.onTarget) {
      unawaited(HapticFeedback.mediumImpact());
    }
    _lastZone = zone;

    final color = switch (zone) {
      ScaleZone.below || null => scheme.onSurfaceVariant,
      ScaleZone.near => Tokens.glow,
      ScaleZone.onTarget => const Color(0xFF2E7D32),
      ScaleZone.over => scheme.error,
    };

    final String hint;
    if (!connected) {
      hint = l10n.scaleNotConnected;
    } else if (net == null) {
      hint = l10n.scaleWaiting;
    } else if (target == null) {
      hint = '';
    } else {
      final diff = (target - net).round().abs();
      hint = switch (zone!) {
        ScaleZone.below || ScaleZone.near => l10n.scaleRemaining(diff),
        ScaleZone.onTarget => l10n.scaleOnTarget,
        ScaleZone.over => l10n.scaleOver(diff),
      };
    }

    final number = Text(
      net == null ? '–' : l10n.scaleGrams(displayGrams(net)),
      style: theme.textTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: zone == ScaleZone.over ? scheme.error : null,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.ingredient != null) ...[
          Text(
            widget.ingredient!,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Tokens.m),
        ],
        Center(
          child: SizedBox.square(
            dimension: widget.size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: target == null
                      ? (net == null ? 0 : 1)
                      : scaleProgress(net ?? 0, target),
                  strokeWidth: 16,
                  strokeCap: StrokeCap.round,
                  color: target == null ? scheme.surfaceContainerHighest : color,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Tokens.l),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(child: number),
                        if (target != null)
                          Text(
                            l10n.scaleOf(target.round()),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Tokens.m),
        SizedBox(
          height: 28,
          child: Text(
            hint,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: zone == null ? scheme.onSurfaceVariant : color,
              fontWeight: zone == ScaleZone.onTarget ? FontWeight.w600 : null,
            ),
          ),
        ),
        const SizedBox(height: Tokens.m),
        BigButton(
          label: l10n.scaleTare,
          icon: Icons.exposure_zero_rounded,
          kind: BigButtonKind.secondary,
          busy: _taring,
          onPressed: live ? _tare : null,
        ),
      ],
    );
  }
}
