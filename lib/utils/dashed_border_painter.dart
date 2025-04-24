import 'dart:ui';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/cupertino.dart';

class DashedBorderPainter extends CustomPainter {
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;
  final Color color;

  DashedBorderPainter({
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
    this.borderRadius = 24.0,
    this.color = CoconutColors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final PathMetrics pathMetrics = path.computeMetrics();

    for (final PathMetric pathMetric in pathMetrics) {
      double distance = 0.0;

      while (distance < pathMetric.length) {
        final next = distance + dashWidth;
        final extractedPath = pathMetric.extractPath(
          distance,
          next.clamp(0.0, pathMetric.length),
        );
        canvas.drawPath(extractedPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
