import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/providers/view_model/send/air-gapped/unsigned_transaction_view_model.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/animated_qr_view.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/view_data_handler/i_qr_view_data_handler.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AdaptiveQrImage extends StatelessWidget {
  const AdaptiveQrImage({
    super.key,
    this.qrData,
    this.qrDensity,
    this.qrViewDataHandler,
    this.embedWidget,
    this.showFrame = true,
    this.qrInternalPadding,
  });

  final String? qrData;
  final QrScanDensity? qrDensity;
  final IQrViewDataHandler? qrViewDataHandler;
  final Widget? embedWidget;
  final bool showFrame;
  final double? qrInternalPadding;

  @override
  Widget build(BuildContext context) {
    assert(qrData != null || qrViewDataHandler != null, 'Either qrData or qrViewDataHandler must be provided');

    final qrContent = LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = _getQrSize(constraints);
        final qrSize = containerSize - (qrInternalPadding ?? 0);

        if (qrData != null) {
          return SizedBox(
            width: containerSize,
            height: containerSize,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  QrImageView(
                    data: qrData!,
                    size: qrSize,
                    backgroundColor: CoconutColors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                  ),
                  if (embedWidget != null) ...[
                    Container(width: 72, height: 72, color: CoconutColors.white),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: context.coconutColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.coconutColors.primaryText.withValues(alpha: 0.08)),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: embedWidget,
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        if (qrViewDataHandler != null) {
          return SizedBox(
            width: containerSize,
            height: containerSize,
            child: Center(
              child: AnimatedQrView(
                key: ValueKey(qrDensity ?? QrScanDensity.normal),
                qrViewDataHandler: qrViewDataHandler!,
                qrScanDensity: qrDensity ?? QrScanDensity.normal,
                qrSize: qrSize,
              ),
            ),
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
