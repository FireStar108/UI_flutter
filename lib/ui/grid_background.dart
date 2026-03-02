import 'package:flutter/material.dart';

enum GridMode { system, grid_2x2, grid_3x3, cinematic }

class GridBackground extends StatelessWidget {
  final GridMode mode;
  const GridBackground({super.key, this.mode = GridMode.system});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GridPainter(mode: mode),
      child: Container(),
    );
  }
}

class GridPainter extends CustomPainter {
  final GridMode mode;
  GridPainter({required this.mode});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final dashedPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 8;
    const dashSpace = 8;

    if (mode == GridMode.system) {
      // Системная сетка (как была раньше)
      final intersectionX = size.width * (10 / 16);
      final intersectionY = size.height * (6 / 9);

      _drawDashedLine(canvas, Offset(intersectionX, 0), Offset(intersectionX, size.height), paint, dashWidth, dashSpace);
      _drawDashedLine(canvas, Offset(0, intersectionY), Offset(size.width, intersectionY), paint, dashWidth, dashSpace);
      
      // Крестик
      _drawCross(canvas, Offset(intersectionX, intersectionY));
    } else if (mode == GridMode.grid_2x2) {
      _drawRegularGrid(canvas, size, 2, 2, paint);
    } else if (mode == GridMode.grid_3x3) {
      _drawRegularGrid(canvas, size, 3, 3, paint);
    } else if (mode == GridMode.cinematic) {
      // Cinematic: упростим до 4x4 или специфических линий (например, 21:9)
      _drawRegularGrid(canvas, size, 4, 4, paint);
      // Добавим рамки сверху/снизу
      final topY = size.height * 0.12;
      final bottomY = size.height * 0.88;
      canvas.drawLine(Offset(0, topY), Offset(size.width, topY), paint..color = Colors.white38);
      canvas.drawLine(Offset(0, bottomY), Offset(size.width, bottomY), paint..color = Colors.white38);
    }
  }

  void _drawRegularGrid(Canvas canvas, Size size, int rows, int cols, Paint paint) {
    for (int i = 1; i < rows; i++) {
      final y = size.height * (i / rows);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (int i = 1; i < cols; i++) {
      final x = size.width * (i / cols);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  void _drawCross(Canvas canvas, Offset center) {
    final crossPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const crossSize = 12.0;
    canvas.drawLine(Offset(center.dx - crossSize, center.dy), Offset(center.dx + crossSize, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - crossSize), Offset(center.dx, center.dy + crossSize), crossPaint);
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
  bool shouldRepaint(covariant GridPainter oldDelegate) => oldDelegate.mode != mode;
}
