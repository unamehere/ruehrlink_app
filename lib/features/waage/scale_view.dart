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
/// So lange muss das Gewicht ruhig im Zielbereich liegen, bevor es als „fertig eingewogen“ gilt.
const scaleSettleTime = Duration(milliseconds: 2500);

/// Danach bleibt „Passt!“ so lange sichtbar (mit Balken und „Hier bleiben“), bevor es weitergeht.
const scaleAdvanceDelay = Duration(seconds: 3);

/// Ruhig heißt: Das Gewicht ändert sich um höchstens so viel (Rieseln zählt nicht als ruhig).
double scaleStillTolerance(double target) => (target * 0.01).clamp(2, 5);

class ScaleView extends ConsumerStatefulWidget {
  const ScaleView({
    super.key,
    this.target,
    this.ingredient,
    this.size = 240,
    this.autoTare = false,
    this.onReached,
    this.onSettled,
  });

  /// Beim ersten Messwert einmal Tara setzen (Kochmodus: jede Zutat für sich wiegen).
  final bool autoTare;

  /// Wird einmal aufgerufen, wenn das Gewicht in den Zielbereich kommt.
  final VoidCallback? onReached;

  /// Wird einmal aufgerufen, wenn das Gewicht [scaleSettleTime] ruhig im Zielbereich lag und
  /// danach [scaleAdvanceDelay] lang „Passt!“ zu sehen war (für „automatisch zur nächsten
  /// Zutat“). Ändert sich das Gewicht oder verlässt es den Bereich, beginnt die Zeit neu;
  /// „Hier bleiben“ bricht ab.
  final VoidCallback? onSettled;

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
  bool _autoTared = false;
  bool _reached = false;
  bool _settled = false;
  Timer? _settle;
  double? _settleFrom;
  Timer? _advance;
  bool _stay = false;
  ScaleZone? _lastZone;

  @override
  void initState() {
    super.initState();
    // Neu zeichnen, damit „verbindet …“ erscheint, wenn keine Werte mehr kommen.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    _settle?.cancel();
    _advance?.cancel();
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

  void _cancelAdvance() {
    _advance?.cancel();
    _advance = null;
  }

  /// „Hier bleiben“: für diese Zutat nicht mehr automatisch weiter.
  void _stayHere() => setState(() {
    _stay = true;
    _settle?.cancel();
    _settle = null;
    _cancelAdvance();
  });

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
    // Tara gibt es erst mit Fähigkeit `scale.tare` (alle bisherigen Firmwares haben sie).
    final canTare =
        ref.watch(bridgeInfoProvider).value?.has('scale.tare') ?? true;

    if (widget.autoTare && canTare && live && !_autoTared) {
      _autoTared = true;
      // nach dem Bauen, nicht währenddessen (setState in _tare)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_tare());
      });
    }
    // Erst nach der Auto-Tara bewerten, sonst zählt der Schüsselinhalt mit.
    final settled = !widget.autoTare || !canTare || (_autoTared && !_taring);
    final zone = net != null && target != null && settled
        ? scaleZone(net, target)
        : null;
    if (zone == ScaleZone.onTarget && _lastZone != ScaleZone.onTarget) {
      unawaited(HapticFeedback.mediumImpact());
      if (!_reached) {
        _reached = true;
        final cb = widget.onReached;
        if (cb != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => cb());
        }
      }
    }
    if (zone == ScaleZone.onTarget && net != null && !_stay) {
      // Noch in Bewegung (z. B. Mehl rieselt nach)? Dann Zeit neu beginnen.
      final from = _settleFrom;
      if (from != null && (net - from).abs() > scaleStillTolerance(target!)) {
        _settle?.cancel();
        _settle = null;
        _cancelAdvance();
      }
      if (_settle == null &&
          _advance == null &&
          !_settled &&
          widget.onSettled != null) {
        _settleFrom = net;
        _settle = Timer(scaleSettleTime, () {
          _settle = null;
          if (!mounted || _settled) return;
          setState(() {
            _advance = Timer(scaleAdvanceDelay, () {
              if (!mounted || _settled) return;
              setState(() {
                _advance = null;
                _settled = true;
              });
              widget.onSettled?.call();
            });
          });
        });
      }
    } else {
      _settle?.cancel();
      _settle = null;
      _settleFrom = null;
      _cancelAdvance();
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
    } else if (net == null || (target != null && zone == null)) {
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
                  color: target == null
                      ? scheme.surfaceContainerHighest
                      : color,
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
        if (_advance != null)
          _Advancing(color: color, onStay: _stayHere)
        else
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
          onPressed: live && canTare ? _tare : null,
        ),
      ],
    );
  }
}

/// „Passt!“ mit ablaufendem Balken, bevor es zur nächsten Zutat geht.
class _Advancing extends StatelessWidget {
  const _Advancing({required this.color, required this.onStay});

  final Color color;
  final VoidCallback onStay;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.scaleAdvancing,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Tokens.s),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: scaleAdvanceDelay,
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: 6,
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        TextButton(onPressed: onStay, child: Text(l10n.scaleStay)),
      ],
    );
  }
}
