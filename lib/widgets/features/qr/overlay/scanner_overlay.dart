import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

class ScannerOverlay extends StatelessWidget {
  final Rect scanWindow;

  const ScannerOverlay({super.key, required this.scanWindow});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ScannerOverlayPainter(scanWindow, context.coconutColors.qrScannerOverlay));
  }

  static Rect calculateScanWindow(Size size) {
    final isWideScreen = size.width > 600;

    final preferredSize =
        (size.width < 400 || size.height < 400)
            ? 320.0
            : isWideScreen
            ? 500.0
            : size.width * 0.85;
    final scanSize = preferredSize.clamp(0.0, size.shortestSide);
    return Rect.fromCenter(center: size.center(Offset.zero), width: scanSize, height: scanSize);
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final Color borderColor;

  _ScannerOverlayPainter(this.scanWindow, this.borderColor);

  @override
  void paint(Canvas canvas, Size size) {
    // saveLayer를 사용해야 BlendMode.clear 제대로 작동
    final layerRect = Offset.zero & size;
    canvas.saveLayer(layerRect, Paint());

    final paint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    canvas.drawRect(layerRect, paint);

    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final rrect = RRect.fromRectAndRadius(scanWindow, const Radius.circular(8));
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
      oldDelegate.scanWindow != scanWindow || oldDelegate.borderColor != borderColor;
}
