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
    this.compact = false,
    this.onTap,
  });

  final BandState state;
  final ApplianceStatus? status;

  /// Anzeige eines Stufenwerts (aus `caps.speeds`); ohne caps die Zahl.
  final String Function(int v)? speedLabel;

  /// Nur eine Zeile (Zustand, Temperatur, Restzeit) – z. B. im Kochen-Tab, wo die Programme führen.
  final bool compact;

  /// Antippen, z. B. zum Auf-/Zuklappen.
  final VoidCallback? onTap;

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
    final keepWarm = s?.keepWarm ?? false;
    final running = (s?.running ?? false) || (s?.active ?? false) || keepWarm;

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
      BandState.ready when keepWarm => l10n.statusKeepWarm,
      BandState.ready when running => l10n.statusRunning,
      BandState.ready => l10n.statusMachineConnected,
    };

    final radius = BorderRadius.circular(Tokens.radius);
    if (compact) {
      return Semantics(
        container: true,
        liveRegion: true,
        button: onTap != null,
        child: Material(
          color: bg,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.m,
                vertical: Tokens.s + 4,
              ),
              child: Row(
                children: [
                  Icon(
                    connected
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: fg,
                    size: 24,
                  ),
                  const SizedBox(width: Tokens.s),
                  Expanded(
                    child: Text(
                      headline,
                      style: theme.textTheme.titleMedium?.copyWith(color: fg),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (s != null) ...[
                    Text(
                      l10n.temperatureValue(s.bowlTemp),
                      style: theme.textTheme.titleMedium?.copyWith(color: fg),
                    ),
                    if (running) ...[
                      const SizedBox(width: Tokens.m),
                      SmoothCountdown(
                        seconds: s.remainingS,
                        running: running,
                        builder: (context, left) => Text(
                          formatDuration(left),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: fg,
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (onTap != null) ...[
                    const SizedBox(width: Tokens.s),
                    Icon(Icons.expand_more_rounded, color: fg),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

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
                      // Ist-Temperatur groß, Ziel klein darunter – spart eine Spalte (F6)
                      _Value(
                        label: l10n.statusBowl,
                        value: l10n.temperatureValue(s.bowlTemp),
                        detail: s.tempSet > 0
                            ? l10n.statusTargetSmall(s.tempSet)
                            : null,
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
                        running: running,
                        builder: (context, left) => _Value(
                          label: l10n.statusRemaining,
                          value: formatDuration(left),
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                  if (s.heating || s.hot || keepWarm) ...[
                    const SizedBox(height: Tokens.m),
                    Wrap(
                      spacing: Tokens.s,
                      runSpacing: Tokens.s,
                      children: [
                        if (keepWarm)
                          _Flag(
                            icon: Icons.soup_kitchen_rounded,
                            text: l10n.statusKeepWarmHint,
                            color: fg,
                          ),
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
  const _Value({
    required this.label,
    required this.value,
    required this.color,
    this.detail,
  });

  final String label;
  final String value;
  final Color color;

  /// Kleine Zusatzzeile unter dem Wert, z. B. „Ziel 40 °C“.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodyMedium?.copyWith(color: color)),
        Text(value, style: text.headlineMedium?.copyWith(color: color)),
        if (detail != null)
          Text(detail!, style: text.bodyMedium?.copyWith(color: color)),
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
