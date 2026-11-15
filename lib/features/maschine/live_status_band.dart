import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_providers.dart';
import '../../ui/widgets/speed_slider.dart';
import '../../ui/widgets/status_band.dart';

/// [StatusBand] mit Live-Daten der Brücke – für alle Bildschirme, die den
/// Maschinenstatus zeigen (Maschine, später Kochen und Kochmodus).
class LiveStatusBand extends ConsumerWidget {
  const LiveStatusBand({super.key, this.compact = false, this.onTap});

  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(applianceStatusProvider);
    final caps = ref.watch(bridgeInfoProvider).value?.readyCaps;
    return switch (status) {
      AsyncValue(:final value?, hasError: false) => StatusBand(
        state: BandState.ready,
        status: value,
        compact: compact,
        onTap: onTap,
        speedLabel: (v) => speedText(context, caps, v),
      ),
      AsyncValue(hasError: true) => StatusBand(
        state: BandState.bridgeUnreachable,
        compact: compact,
        onTap: onTap,
      ),
      _ => StatusBand(
        state: BandState.connecting,
        compact: compact,
        onTap: onTap,
      ),
    };
  }
}
