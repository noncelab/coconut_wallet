import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final scanAreaSize = calculateScanAreaSize(context);

    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _ScannerOverlayPainter(scanAreaSize, context.coconutColors.qrScannerOverlay),
    );
  }

  static double calculateScanAreaSize(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWideScreen = size.width > 600;

    return (size.width < 400 || size.height < 400)
        ? 320.0
        : isWideScreen
        ? 500.0
        : size.width * 0.85;
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double scanSize;
  final Color borderColor;

  _ScannerOverlayPainter(this.scanSize, this.borderColor);

  @override
  void paint(Canvas canvas, Size size) {
    // saveLayer를 사용해야 BlendMode.clear 제대로 작동
    final layerRect = Offset.zero & size;
    canvas.saveLayer(layerRect, Paint());

    final paint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    canvas.drawRect(layerRect, paint);

    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: scanSize, height: scanSize);

    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, clearPaint);

    canvas.restore();

    final borderPaint =
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.scanSize != scanSize || oldDelegate.borderColor != borderColor;
}
