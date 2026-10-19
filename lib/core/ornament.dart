import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

class Rosette extends StatelessWidget {
  const Rosette({super.key, this.size = 44, this.label, this.color});
  final double size;
  final String? label;
  final Color? color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _RosettePainter(color ?? SuwarColors.gold),
      child: Center(
        child: label == null
            ? null
            : Text(
                label!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: size > 50 ? 16 : 12,
                  color: color ?? SuwarColors.goldText,
                ),
              ),
      ),
    ),
  );
}

class _RosettePainter extends CustomPainter {
  _RosettePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final a = -math.pi / 2 + i * math.pi / 8;
      final r = size.shortestSide * (i.isEven ? .5 : .375);
      final p = Offset(
        size.width / 2 + r * math.cos(a),
        size.height / 2 + r * math.sin(a),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_RosettePainter oldDelegate) => color != oldDelegate.color;
}

class GeometricOrnament extends StatelessWidget {
  const GeometricOrnament({
    super.key,
    this.size = 140,
    this.color = const Color(0xFF376052),
  });
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Rosette(size: size, color: color),
          Rosette(size: size * .5, color: color),
          CustomPaint(size: Size.square(size), painter: _OrnamentLines(color)),
        ],
      ),
    ),
  );
}

class _OrnamentLines extends CustomPainter {
  const _OrnamentLines(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width,
        h = size.height,
        p = Paint()
          ..color = color
          ..strokeWidth = .8;
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), p);
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), p);
    canvas.drawLine(
      Offset(w * 3.5 / 24, h * 3.5 / 24),
      Offset(w * 20.5 / 24, h * 20.5 / 24),
      p,
    );
    canvas.drawLine(
      Offset(w * 20.5 / 24, h * 3.5 / 24),
      Offset(w * 3.5 / 24, h * 20.5 / 24),
      p,
    );
  }

  @override
  bool shouldRepaint(_OrnamentLines oldDelegate) => color != oldDelegate.color;
}
