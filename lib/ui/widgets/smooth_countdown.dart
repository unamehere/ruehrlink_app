import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Restzeit, die in der App flüssig jede Sekunde herunterzählt.
///
/// Die Maschine meldet ihre Restzeit nicht exakt im Sekundentakt (mal 2 s Abstand, mal zwei Meldungen in
/// einer Sekunde – Fehlerliste F13). Deshalb zählt die Anzeige selbst und gleicht sich mit der Maschine ab:
/// Weicht die Meldung um 2 s oder mehr ab (z. B. neuer Schritt), wird sie übernommen.
class SmoothCountdown extends StatefulWidget {
  const SmoothCountdown({
    super.key,
    required this.seconds,
    required this.running,
    required this.builder,
  });

  /// Zuletzt von der Maschine gemeldete Restzeit.
  final int seconds;

  /// Nur während des Laufs wird lokal gezählt.
  final bool running;
  final Widget Function(BuildContext context, int seconds) builder;

  @override
  State<SmoothCountdown> createState() => _SmoothCountdownState();
}

class _SmoothCountdownState extends State<SmoothCountdown> {
  late int _anchorValue = widget.seconds;
  final _clock = Stopwatch()..start();
  Timer? _timer;

  int get _local {
    if (!widget.running) return widget.seconds;
    final v = _anchorValue - _clock.elapsedMilliseconds ~/ 1000;
    return v < 0 ? 0 : v;
  }

  void _anchor(int value) {
    _anchorValue = value;
    _clock
      ..reset()
      ..start();
  }

  void _updateTimer() {
    if (widget.running && _timer == null) {
      _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
    } else if (!widget.running) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _updateTimer();
  }

  @override
  void didUpdateWidget(SmoothCountdown old) {
    super.didUpdateWidget(old);
    if (widget.seconds != old.seconds || widget.running != old.running) {
      final local = _local;
      final diff = widget.seconds - local;
      // ±1 s ist nur das ungleichmäßige Melden der Maschine – lokal weiterzählen, sonst springt es.
      if (!widget.running || !old.running || diff.abs() >= 2) {
        _anchor(widget.seconds);
      }
    }
    _updateTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _local);
}
