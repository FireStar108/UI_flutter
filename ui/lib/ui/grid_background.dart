import 'package:flutter/material.dart';
import '../core/grid_models.dart';

class GridBackground extends StatelessWidget {
  final GridMode mode;
  final GridMetadata? customMetadata;
  const GridBackground({super.key, this.mode = GridMode.system, this.customMetadata});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GridPainter(mode: mode, customMetadata: customMetadata),
      child: Container(),
    );
  }
}

class GridPainter extends CustomPainter {
  final GridMode mode;
  final GridMetadata? customMetadata;
  GridPainter({required this.mode, this.customMetadata});
  @override
  void paint(Canvas canvas, Size size) {
    final metadata = GridMetadata.fromMode(mode, customData: customMetadata);
    
    final paint = Paint()
      ..color = metadata.color.withValues(alpha: 0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final int dashWidth = 8;
    final int dashSpace = 8;

    // Отрисовка всех линий (глобальных и in-box)
    final vLines = metadata.computeVisualLines();
    for (var vLine in vLines) {
      final start = Offset(vLine.start.dx * size.width, vLine.start.dy * size.height);
      final end = Offset(vLine.end.dx * size.width, vLine.end.dy * size.height);
      _drawDashedLine(canvas, start, end, paint, dashWidth, dashSpace);
    }

    // Отрисовка крестиков на пересечениях (только для системной сетки по умолчанию)
    if (mode == GridMode.system) {
      _drawCross(canvas, Offset(size.width * (10 / 16), size.height * (6 / 9)));
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
  bool shouldRepaint(covariant GridPainter oldDelegate) => 
      oldDelegate.mode != mode || oldDelegate.customMetadata != customMetadata;
}
