import 'package:flutter/material.dart';

/// Stroke paths from the saved FigCraft icon set (24px authoring viewbox).
enum SuwarSymbol {
  home,
  book,
  learning,
  prayer,
  back,
  settings,
  search,
  play,
  pause,
  eye,
  refresh,
  check,
  download,
  pin,
}

class SuwarIcon extends StatelessWidget {
  const SuwarIcon(this.symbol, {super.key, this.size = 24, this.color});
  final SuwarSymbol symbol;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _IconPainter(
          symbol,
          color ?? IconTheme.of(context).color ?? const Color(0xFF173F35),
        ),
      ),
    ),
  );
}

class _IconPainter extends CustomPainter {
  const _IconPainter(this.symbol, this.color);
  final SuwarSymbol symbol;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale);
    final p = Path();
    switch (symbol) {
      case SuwarSymbol.home:
        p.moveTo(3, 11);
        p.lineTo(12, 3);
        p.lineTo(21, 11);
        p.moveTo(5, 10);
        p.lineTo(5, 21);
        p.lineTo(9, 21);
        p.lineTo(9, 15);
        p.lineTo(15, 15);
        p.lineTo(15, 21);
        p.lineTo(19, 21);
        p.lineTo(19, 10);
      case SuwarSymbol.book:
        p.moveTo(12, 5);
        p.cubicTo(8, 2, 4, 3, 2, 4);
        p.lineTo(2, 20);
        p.cubicTo(5, 18, 9, 18, 12, 21);
        p.cubicTo(15, 18, 19, 18, 22, 20);
        p.lineTo(22, 4);
        p.cubicTo(19, 3, 15, 2, 12, 5);
        p.lineTo(12, 21);
      case SuwarSymbol.learning:
        p.moveTo(4, 3);
        p.lineTo(18, 3);
        p.lineTo(18, 12);
        p.moveTo(4, 3);
        p.lineTo(4, 20);
        p.lineTo(12, 20);
        p.moveTo(4, 16);
        p.lineTo(11, 16);
        p.moveTo(14, 18);
        p.lineTo(17, 21);
        p.lineTo(23, 14);
      case SuwarSymbol.prayer:
        p.moveTo(4, 21);
        p.lineTo(4, 11);
        p.lineTo(12, 5);
        p.lineTo(20, 11);
        p.lineTo(20, 21);
        p.close();
        p.moveTo(9, 21);
        p.lineTo(9, 15);
        p.quadraticBezierTo(12, 10, 15, 15);
        p.lineTo(15, 21);
        p.moveTo(12, 5);
        p.lineTo(12, 1);
      case SuwarSymbol.back:
        p.moveTo(9, 4);
        p.lineTo(17, 12);
        p.lineTo(9, 20);
      case SuwarSymbol.settings:
        for (final y in [6.0, 12.0, 18.0]) {
          p.moveTo(4, y);
          p.lineTo(20, y);
        }
        p.moveTo(8, 3);
        p.lineTo(8, 9);
        p.moveTo(16, 9);
        p.lineTo(16, 15);
        p.moveTo(10, 15);
        p.lineTo(10, 21);
      case SuwarSymbol.search:
        p.addOval(Rect.fromCircle(center: const Offset(10, 10), radius: 6));
        p.moveTo(15, 15);
        p.lineTo(21, 21);
      case SuwarSymbol.play:
        p.moveTo(7, 3);
        p.lineTo(21, 12);
        p.lineTo(7, 21);
        p.close();
      case SuwarSymbol.pause:
        p.moveTo(7, 4);
        p.lineTo(7, 20);
        p.moveTo(17, 4);
        p.lineTo(17, 20);
      case SuwarSymbol.eye:
        p.moveTo(2, 12);
        p.quadraticBezierTo(12, 1, 22, 12);
        p.quadraticBezierTo(12, 23, 2, 12);
        p.close();
        p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 3));
      case SuwarSymbol.refresh:
        p.moveTo(20, 8);
        p.cubicTo(17, 1, 9, 1, 6, 5);
        p.lineTo(3, 8);
        p.moveTo(3, 3);
        p.lineTo(3, 8);
        p.lineTo(8, 8);
        p.moveTo(4, 16);
        p.cubicTo(7, 23, 15, 23, 18, 19);
        p.lineTo(21, 16);
        p.moveTo(16, 16);
        p.lineTo(21, 16);
        p.lineTo(21, 21);
      case SuwarSymbol.check:
        p.moveTo(4, 12);
        p.lineTo(9, 17);
        p.lineTo(20, 6);
      case SuwarSymbol.download:
        p.moveTo(12, 2);
        p.lineTo(12, 16);
        p.moveTo(6, 10);
        p.lineTo(12, 16);
        p.lineTo(18, 10);
        p.moveTo(4, 17);
        p.lineTo(4, 22);
        p.lineTo(20, 22);
        p.lineTo(20, 17);
      case SuwarSymbol.pin:
        p.moveTo(12, 22);
        p.cubicTo(9, 18, 4, 13, 4, 9);
        p.arcToPoint(const Offset(20, 9), radius: const Radius.circular(8));
        p.cubicTo(20, 13, 15, 18, 12, 22);
        p.close();
        p.addOval(Rect.fromCircle(center: const Offset(12, 9), radius: 3));
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7 / scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      symbol != oldDelegate.symbol || color != oldDelegate.color;
}
