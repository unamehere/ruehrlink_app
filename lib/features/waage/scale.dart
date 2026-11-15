import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/bridge_api.dart';
import '../../core/api/bridge_providers.dart';
import '../../core/models/models.dart';

/// Ein Messwert der Waage.
class ScaleReading {
  const ScaleReading({required this.net, this.gross, required this.at});

  /// Gramm nach Tara.
  final double net;

  /// Rohwert der Maschine (ohne Tara), `null` bei älterer Firmware.
  final double? gross;

  /// Wann die App den Wert bekommen hat.
  final DateTime at;
}

/// Ab so langer Stille gilt die Waage als „verbindet …“ statt live.
const scaleStaleAfter = Duration(seconds: 3);

/// So oft erneuert die App die Waage auf der Brücke (Lease 30 s).
const _renewEvery = Duration(seconds: 10);
const _leaseSeconds = 30;

/// Live-Werte der Waage. Solange jemand zuhört, erneuert die App alle 10 s die Waage auf der
/// Brücke (`POST /scale/watch`) – hört niemand mehr zu, schaltet die Brücke sie nach 30 s ab.
/// Das spart der Brücke RAM (eigene TLS-Verbindung zur Maschine).
final scaleProvider = StreamProvider.autoDispose<ScaleReading>((ref) async* {
  final api = ref.watch(bridgeApiProvider);
  Future<void> renew() async {
    try {
      await api.watchScale(seconds: _leaseSeconds);
    } on BridgeException {
      // Maschine nicht verbunden / keine Waage: die Anzeige zeigt das am Status.
    }
  }

  unawaited(renew());
  final timer = Timer.periodic(_renewEvery, (_) => renew());
  ref.onDispose(timer.cancel);

  await for (final e in api.events()) {
    if (e is WeightEvent) {
      yield ScaleReading(net: e.grams, gross: e.gross, at: DateTime.now());
    }
  }
});

/// Wie nah das Gewicht am Ziel ist.
enum ScaleZone {
  /// Noch deutlich zu wenig.
  below,

  /// Fast da (ab 85 % des Ziels).
  near,

  /// Im Zielbereich.
  onTarget,

  /// Zu viel.
  over,
}

/// Erlaubte Abweichung vom Ziel: 3 %, mindestens 2 g (Salz, Hefe).
double scaleTolerance(double target) => max(2, target * 0.03);

ScaleZone scaleZone(double net, double target) {
  final tol = scaleTolerance(target);
  if (net > target + tol) return ScaleZone.over;
  if (net >= target - tol) return ScaleZone.onTarget;
  if (net >= target * 0.85) return ScaleZone.near;
  return ScaleZone.below;
}

/// Füllstand des Rings 0…1 (zu viel bleibt voll; die Farbe zeigt es).
double scaleProgress(double net, double target) =>
    target <= 0 ? 0 : (net / target).clamp(0.0, 1.0);

/// Anzeigewert: auf ganze Gramm, kleines Zittern um 0 als „0“.
int displayGrams(double net) => net.abs() < 0.5 ? 0 : net.round();
