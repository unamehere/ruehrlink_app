import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../l10n/l10n.dart';
import '../format.dart';
import '../theme.dart';
import 'smooth_countdown.dart';

/// Verbindungszustand für das [StatusBand].
enum BandState { connecting, bridgeUnreachable, ready }

/// Großes Statusband: verbunden? · läuft? · Schüssel (Ist/Ziel) · Stufe · Restzeit,
/// dazu „Heizt“ und „Schüssel heiß“. Wird in „Kochen“, „Maschine“ und später im
/// Kochmodus gezeigt.
class StatusBand extends StatelessWidget {
  const StatusBand({
    super.key,
    required this.state,
    this.status,
    this.speedLabel,
  });

  final BandState state;
  final ApplianceStatus? status;

  /// Anzeige eines Stufenwerts (aus `caps.speeds`); ohne caps die Zahl.
  final String Function(int v)? speedLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Werte nur zeigen, wenn Brücke erreichbar und Gerät verbunden ist.
    final s = state == BandState.ready && (status?.connected ?? false)
        ? status
        : null;
    final connected = s != null;
    final running = s?.running ?? false;

    final (Color bg, Color fg) = switch ((state, connected, running)) {
      (BandState.bridgeUnreachable, _, _) => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      (_, _, true) => (scheme.primary, scheme.onPrimary),
      (_, true, _) => (scheme.primaryContainer, scheme.onPrimaryContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurface),
    };

    final headline = switch (state) {
      BandState.connecting => l10n.statusConnecting,
      BandState.bridgeUnreachable => l10n.statusBridgeUnreachable,
      BandState.ready when !connected => l10n.statusMachineDisconnected,
      BandState.ready when running => l10n.statusRunning,
      BandState.ready => l10n.statusMachineConnected,
    };

    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Tokens.radius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Tokens.m + 4),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: fg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      connected
                          ? Icons.check_circle_rounded
                          : (state == BandState.connecting
                                ? Icons.sync_rounded
                                : Icons.cancel_rounded),
                      color: fg,
                      size: 30,
                    ),
                    const SizedBox(width: Tokens.s + 4),
                    Expanded(
                      child: Text(
                        headline,
                        style: theme.textTheme.titleLarge?.copyWith(color: fg),
                      ),
                    ),
                  ],
                ),
                if (s != null) ...[
                  const SizedBox(height: Tokens.m),
                  Wrap(
                    spacing: Tokens.xl,
                    runSpacing: Tokens.m,
                    children: [
                      _Value(
                        label: l10n.statusBowl,
                        value: l10n.temperatureValue(s.bowlTemp),
                        color: fg,
                      ),
                      if (s.tempSet > 0)
                        _Value(
                          label: l10n.statusTarget,
                          value: l10n.temperatureValue(s.tempSet),
                          color: fg,
                        ),
                      _Value(
                        label: l10n.dialSpeed,
                        value: s.speedSet == 0
                            ? l10n.valueOff
                            : (speedLabel?.call(s.speedSet) ?? '${s.speedSet}'),
                        color: fg,
                      ),
                      SmoothCountdown(
                        seconds: s.remainingS,
                        running: s.running || s.active,
                        builder: (context, left) => _Value(
                          label: l10n.statusRemaining,
                          value: formatDuration(left),
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                  if (s.heating || s.hot) ...[
                    const SizedBox(height: Tokens.m),
                    Wrap(
                      spacing: Tokens.s,
                      runSpacing: Tokens.s,
                      children: [
                        if (s.heating)
                          _Flag(
                            icon: Icons.local_fire_department_rounded,
                            text: l10n.statusHeating,
                            color: fg,
                          ),
                        if (s.hot)
                          _Flag(
                            icon: Icons.warning_amber_rounded,
                            text: l10n.statusHot,
                            color: fg,
                          ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodyMedium?.copyWith(color: color)),
        Text(value, style: text.headlineMedium?.copyWith(color: color)),
      ],
    );
  }
}

/// Kleiner Hinweis im Band, z. B. „Heizt“ oder „Schüssel heiß“.
class _Flag extends StatelessWidget {
  const _Flag({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: color, width: 2),
      borderRadius: BorderRadius.circular(Tokens.radius),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.m,
        vertical: Tokens.s,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: Tokens.s),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    ),
  );
}
