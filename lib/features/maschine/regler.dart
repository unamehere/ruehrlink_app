import '../../core/models/models.dart';
import '../../ui/input.dart';

/// Schrittweiten für Temperatur und Zeit. (Stufen sind eine Auswahlliste aus
/// `caps.speeds`, siehe `SpeedPicker`.) Grenzen kommen immer aus den [ApplianceCaps];
/// fest stehen nur die Schrittweiten (eine Bedien-, keine Geräteentscheidung).
///
/// Jede Funktion liefert den nächsten Wert oder `null`, wenn die Grenze erreicht
/// ist – dann wird die Taste gesperrt.
abstract final class Regler {
  static const tempStep = 5;

  /// Temperatur: 0 (aus) ↔ tempMin ↔ … in 5-°C-Schritten ↔ tempMax.
  static int? temperature(ApplianceCaps caps, int t, {required bool up}) {
    final current = caps.clampTemperature(t);
    final int next;
    if (up) {
      if (current >= caps.tempMax) return null;
      next = current == 0
          ? caps.tempMin
          : ((current ~/ tempStep) + 1) * tempStep;
    } else {
      if (current == 0) return null;
      next = current <= caps.tempMin
          ? 0
          : ((current - 1) ~/ tempStep) * tempStep;
    }
    final clamped = up
        ? (next > caps.tempMax ? caps.tempMax : next)
        : (next != 0 && next < caps.tempMin ? caps.tempMin : next);
    return clamped == current ? null : clamped;
  }

  /// Zeit: feine Schritte bei kurzen Zeiten, grobe bei langen.
  static int? time(ApplianceCaps caps, int seconds, {required bool up}) {
    final current = caps.clampTime(seconds);
    if (up && current >= caps.timeMaxS) return null;
    if (!up && current <= 0) return null;
    final step = _timeStep(up ? current : current - 1);
    final next = up
        ? (current ~/ step + 1) * step
        : ((current - 1) ~/ step) * step;
    return caps.clampTime(next);
  }

  static int _timeStep(int s) => switch (s) {
    < 120 => 10,
    < 600 => 30,
    < 3600 => 60,
    _ => 300,
  };

  /// Eingetippte Temperatur: leer oder 0 = aus, sonst tempMin–tempMax.
  /// `null` = ungültig (wird markiert, nicht angepasst).
  static int? parseTemperature(ApplianceCaps caps, String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    final v = int.tryParse(t);
    if (v == null) return null;
    if (v == 0) return 0;
    return v >= caps.tempMin && v <= caps.tempMax ? v : null;
  }

  /// Eingetippte Zeit (`1:30`, `1:05:00`, `90`), höchstens timeMaxS.
  static int? parseTime(ApplianceCaps caps, String text) {
    final v = parseDurationText(text);
    return v != null && v <= caps.timeMaxS ? v : null;
  }
}
