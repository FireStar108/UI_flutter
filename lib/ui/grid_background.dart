import 'package:flutter/material.dart';

class GridBackground extends StatelessWidget {
  const GridBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GridPainter(),
      child: Container(),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 3.0 // Вернули умеренную толщину
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 8.0;

    // Точка пересечения
    final intersectionX = size.width * (10 / 16);
    final intersectionY = size.height * (6 / 9);

    // Вертикальная линия
    _drawDashedLine(
      canvas,
      Offset(intersectionX, 0),
      Offset(intersectionX, size.height),
      paint,
      dashWidth.toInt(),
      dashSpace.toInt(),
    );

    // Горизонтальная линия
    _drawDashedLine(
      canvas,
      Offset(0, intersectionY),
      Offset(size.width, intersectionY),
      paint,
      dashWidth.toInt(),
      dashSpace.toInt(),
    );

    // Отрисовка аккуратного крестика на пересечении
    final crossPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const crossSize = 12.0;
    // Горизонтальная палочка крестика
    canvas.drawLine(
      Offset(intersectionX - crossSize, intersectionY),
      Offset(intersectionX + crossSize, intersectionY),
      crossPaint,
    );
    // Вертикальная палочка крестика
    canvas.drawLine(
      Offset(intersectionX, intersectionY - crossSize),
      Offset(intersectionX, intersectionY + crossSize),
      crossPaint,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint,
      int dashWidth, int dashSpace) {
    double distance = (end - start).distance;
    for (double i = 0; i < distance; i += dashWidth + dashSpace) {
      canvas.drawPath(
        Path()
          ..moveTo(
            start.dx + (end.dx - start.dx) * (i / distance),
            start.dy + (end.dy - start.dy) * (i / distance),
          )
          ..lineTo(
            start.dx + (end.dx - start.dx) * ((i + dashWidth) / distance),
            start.dy + (end.dy - start.dy) * ((i + dashWidth) / distance),
          ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
