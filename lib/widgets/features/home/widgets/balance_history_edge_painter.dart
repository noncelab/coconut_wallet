import 'package:flutter/material.dart';

class BalanceHistoryEdgePainter extends CustomPainter {
  final double overscroll;
  final Color color;
  const BalanceHistoryEdgePainter(this.overscroll, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || overscroll.abs() < 0.1) return;
    final extent = (overscroll.abs() / 4).clamp(0.0, 24.0);
    final right = overscroll > 0;
    final x = right ? size.width : 0.0;
    final direction = right ? -1 : 1;
    final edge =
        Path()
          ..moveTo(x, 0)
          ..quadraticBezierTo(x + direction * extent * 2, size.height / 2, x, size.height)
          ..close();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(
      edge,
      Paint()
        ..shader = LinearGradient(
          begin: right ? Alignment.centerRight : Alignment.centerLeft,
          end: right ? Alignment.centerLeft : Alignment.centerRight,
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(right ? size.width - extent : 0, 0, extent, size.height)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BalanceHistoryEdgePainter oldDelegate) =>
      overscroll != oldDelegate.overscroll || color != oldDelegate.color;
}
