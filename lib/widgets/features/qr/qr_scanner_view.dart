import 'package:coconut_wallet/widgets/features/qr/overlay/scanner_overlay.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerView extends StatelessWidget {
  final Key? scannerKey;
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final Widget Function(BuildContext, MobileScannerException) errorBuilder;
  final Widget Function(BuildContext, Rect)? overlayBuilder;

  const QrScannerView({
    super.key,
    this.scannerKey,
    required this.controller,
    required this.onDetect,
    required this.errorBuilder,
    this.overlayBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanWindow = ScannerOverlay.calculateScanWindow(constraints.biggest);
        return Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              key: scannerKey,
              controller: controller,
              onDetect: onDetect,
              errorBuilder: errorBuilder,
              scanWindow: scanWindow,
            ),
            ScannerOverlay(scanWindow: scanWindow),
            if (overlayBuilder != null) overlayBuilder!(context, scanWindow),
          ],
        );
      },
    );
  }
}
