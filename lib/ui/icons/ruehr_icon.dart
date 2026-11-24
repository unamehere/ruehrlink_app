import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Eigenes Symbol „Rühren“: Schüssel, schräger Kochlöffel, kreisende Bewegung darum.
///
/// Gleicher Strichstil wie das Rührlink-Zeichen (`ruehrlink_hardware/gehaeuse/logo`): 64er-Raster,
/// Strich 3,2, runde Enden. Bewusst eigener Entwurf, keine Herstellergrafik. Farbe und Größe wie bei
/// [Icon] aus dem [IconTheme], damit es überall statt eines Material-Symbols stehen kann.
class RuehrIcon extends StatelessWidget {
  const RuehrIcon({super.key, this.size, this.color, this.semanticLabel});

  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    final c = color ?? theme.color ?? const Color(0xFF24262B);
    final icon = SizedBox.square(
      dimension: s,
      child: CustomPaint(painter: RuehrIconPainter(c)),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: icon)
        : Semantics(label: semanticLabel, child: icon);
  }
}

class RuehrIconPainter extends CustomPainter {
  const RuehrIconPainter(this.color);

  final Color color;

  // Kochlöffel: Stiel von oben rechts schräg in die Schüssel, gefüllte Laffe am Rand.
  static const _handleTop = Offset(47, 6);
  static const _handleEnd = Offset(37.5, 29);
  static const _headLength = 15.0;
  static const _headWidth = 9.5;

  // Rührbewegung: Ellipse um den Stiel über der Schüssel, hinten offen.
  static const _orbitCenter = Offset(41, 15.5);
  static const _orbitRx = 13.5;
  static const _orbitRy = 4.6;
  static const _orbitStart = -0.30 * math.pi; // oben rechts
  static const _orbitSweep =
      1.15 * math.pi; // im Uhrzeigersinn über vorne nach links

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 64;
    canvas.save();
    canvas.scale(k);
    canvas.saveLayer(Offset.zero & const Size(64, 64), Paint());

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    // Lücke um Linien, die vorne liegen (wie in Strichzeichnungen üblich).
    final gap = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 + 4.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Schüssel (wie im Zeichen)
    canvas.drawPath(
      Path()
        ..moveTo(10, 38)
        ..lineTo(54, 38)
        ..arcToPoint(
          const Offset(10, 38),
          radius: const Radius.elliptical(22, 16),
        ),
      stroke,
    );

    // Kochlöffel vor dem Rand
    final dir = _handleEnd - _handleTop;
    final unit = dir / dir.distance;
    final headCenter = _handleEnd + unit * (_headLength / 2 - 1);
    final head = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: _headWidth,
          height: _headLength,
        ),
      );
    final headPath = head.transform(
      (Matrix4.identity()
            ..translateByDouble(headCenter.dx, headCenter.dy, 0, 1)
            ..rotateZ(math.atan2(unit.dy, unit.dx) - math.pi / 2))
          .storage,
    );
    final handle = Path()
      ..moveTo(_handleTop.dx, _handleTop.dy)
      ..lineTo(_handleEnd.dx, _handleEnd.dy);
    canvas.drawPath(headPath, gap);
    canvas.drawPath(handle, gap);
    canvas.drawPath(handle, stroke);
    canvas.drawPath(headPath, fill);

    // Rührbewegung vor dem Stiel, mit Pfeilspitze am Ende
    final orbit = Path()
      ..addArc(
        Rect.fromCenter(
          center: _orbitCenter,
          width: _orbitRx * 2,
          height: _orbitRy * 2,
        ),
        _orbitStart,
        _orbitSweep,
      );
    // Lücke nur dort, wo der Bogen vorne über den Stiel läuft – hinten bleibt der Stiel ganz.
    canvas.drawPath(
      Path()..addArc(
        Rect.fromCenter(
          center: _orbitCenter,
          width: _orbitRx * 2,
          height: _orbitRy * 2,
        ),
        0.25 * math.pi,
        0.5 * math.pi,
      ),
      gap,
    );
    canvas.drawPath(orbit, stroke);

    const end = _orbitStart + _orbitSweep;
    final tip = Offset(
      _orbitCenter.dx + _orbitRx * math.cos(end),
      _orbitCenter.dy + _orbitRy * math.sin(end),
    );
    final tangent = Offset(-_orbitRx * math.sin(end), _orbitRy * math.cos(end));
    final t = tangent / tangent.distance;
    final n = Offset(-t.dy, t.dx);
    const len = 4.6;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx - (t.dx - n.dx) * len, tip.dy - (t.dy - n.dy) * len)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - (t.dx + n.dx) * len, tip.dy - (t.dy + n.dy) * len),
      stroke,
    );

    canvas.restore(); // Ebene
    canvas.restore(); // Skalierung
  }

  @override
  bool shouldRepaint(RuehrIconPainter old) => old.color != color;
}
