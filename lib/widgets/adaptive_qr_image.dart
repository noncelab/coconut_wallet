import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/providers/view_model/send/unsigned_transaction_view_model.dart';
import 'package:coconut_wallet/screens/send/unsigned_transaction_qr_screen.dart';
import 'package:coconut_wallet/widgets/animated_qr/animated_qr_view.dart';
import 'package:coconut_wallet/widgets/animated_qr/view_data_handler/i_qr_view_data_handler.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AdaptiveQrImage extends StatelessWidget {
  const AdaptiveQrImage({super.key, this.qrData, this.qrDensity, this.qrViewDataHandler});

  final String? qrData;
  final QrScanDensity? qrDensity;
  final IQrViewDataHandler? qrViewDataHandler;

  @override
  Widget build(BuildContext context) {
    assert(qrData != null || qrViewDataHandler != null, 'Either qrData or qrViewDataHandler must be provided');

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: CoconutBoxDecoration.shadowBoxDecoration,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final qrSize = _getQrSize(constraints);
          if (qrData != null) {
            return QrImageView(data: qrData!, size: qrSize);
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
      ),
    );
  }

  double _getQrSize(BoxConstraints constraints) {
    final shortestScreenWidth = math.min(constraints.maxWidth, constraints.maxHeight);
    return shortestScreenWidth.clamp(220, 360);
  }
}
