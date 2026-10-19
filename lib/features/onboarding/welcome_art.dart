import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class WelcomeArt extends StatelessWidget {
  const WelcomeArt({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 317,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: -45,
          top: 31,
          child: GeometricOrnament(size: 180, color: Color(0xFF3D6253)),
        ),
        const Positioned(
          right: -30,
          top: 196,
          child: GeometricOrnament(size: 160, color: Color(0xFF3D6253)),
        ),
        Positioned.fill(child: CustomPaint(painter: _WelcomeArch())),
        const Positioned(
          top: 121,
          left: 0,
          right: 0,
          child: Center(child: Rosette(size: 40)),
        ),
        const Positioned(
          top: 203,
          left: 0,
          right: 0,
          child: Center(
            child: SuwarIcon(
              SuwarSymbol.book,
              size: 82,
              color: SuwarColors.ivory,
            ),
          ),
        ),
      ],
    ),
  );
}

class _WelcomeArch extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void arch(
      double width,
      double height,
      double top,
      Color color,
      bool closed,
    ) {
      final path = Path()
        ..moveTo(0, 220)
        ..lineTo(0, 100)
        ..cubicTo(0, 55, 55, 40, 100, 0)
        ..cubicTo(145, 40, 200, 55, 200, 100)
        ..lineTo(200, 220);
      if (closed) path.close();
      canvas.save();
      canvas.translate((size.width - width) / 2, top);
      canvas.scale(width / 200, height / 220);
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = closed ? 1.2 : .9,
      );
      canvas.restore();
    }

    arch(214, 248, 58, SuwarColors.gold, true);
    arch(176, 202, 81, const Color(0xFF49705E), false);
  }

  @override
  bool shouldRepaint(_WelcomeArch oldDelegate) => false;
}
