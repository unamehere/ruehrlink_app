import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/bridge_providers.dart';
import '../../ui/widgets/status_band.dart';

/// [StatusBand] mit Live-Daten der Brücke – für alle Bildschirme, die den
/// Maschinenstatus zeigen (Maschine, später Kochen und Kochmodus).
class LiveStatusBand extends ConsumerWidget {
  const LiveStatusBand({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(applianceStatusProvider);
    return switch (status) {
      AsyncValue(:final value?, hasError: false) => StatusBand(
        state: BandState.ready,
        status: value,
      ),
      AsyncValue(hasError: true) => const StatusBand(
        state: BandState.bridgeUnreachable,
      ),
      _ => const StatusBand(state: BandState.connecting),
    };
  }
}
