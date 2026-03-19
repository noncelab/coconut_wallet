import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/providers/view_model/send/unsigned_transaction_view_model.dart';
import 'package:coconut_wallet/widgets/animated_qr/animated_qr_view.dart';
import 'package:coconut_wallet/widgets/animated_qr/view_data_handler/i_qr_view_data_handler.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AdaptiveQrImage extends StatelessWidget {
  const AdaptiveQrImage({
    super.key,
    this.qrData,
    this.qrDensity,
    this.qrViewDataHandler,
    this.embedImage,
    this.showFrame = true,
  });

  final String? qrData;
  final QrScanDensity? qrDensity;
  final IQrViewDataHandler? qrViewDataHandler;
  final ImageProvider? embedImage;
  final bool showFrame;

  @override
  Widget build(BuildContext context) {
    assert(qrData != null || qrViewDataHandler != null, 'Either qrData or qrViewDataHandler must be provided');

    final qrContent = LayoutBuilder(
      builder: (context, constraints) {
        final qrSize = _getQrSize(constraints);
        if (qrData != null) {
          return Stack(
            alignment: Alignment.center,
            children: [
              QrImageView(
                data: qrData!,
                size: qrSize,
                backgroundColor: CoconutColors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
              if (embedImage != null) ...[
                Container(width: 72, height: 72, color: CoconutColors.white),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: CoconutColors.black, borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.all(6),
                  child: Image(image: embedImage!, width: 20, height: 20),
                ),
              ],
            ],
          );
        }

        if (qrViewDataHandler != null) {
          return AnimatedQrView(
            key: ValueKey(qrDensity ?? QrScanDensity.normal),
            qrViewDataHandler: qrViewDataHandler!,
            qrScanDensity: qrDensity ?? QrScanDensity.normal,
            qrSize: qrSize,
          );
        }

        return const SizedBox.shrink();
      },
    );

    if (!showFrame) {
      return qrContent;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: CoconutBoxDecoration.shadowBoxDecoration,
      child: qrContent,
    );
  }

  double _getQrSize(BoxConstraints constraints) {
    final shortestScreenWidth = math.min(constraints.maxWidth, constraints.maxHeight);
    return shortestScreenWidth.clamp(220, 360);
  }
}
