import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCode extends StatefulWidget {
  final String qrData;
  const QrCode({super.key, required this.qrData});

  @override
  State<QrCode> createState() => _QrCodeState();
}

class _QrCodeState extends State<QrCode> {
  @override
  Widget build(BuildContext context) {
    final double qrSize = MediaQuery.of(context).size.width * 275 / 375;

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                Container(
                  width: qrSize,
                  height: qrSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
                    color: CoconutColors.white,
                  ),
                ),
                QrImageView(
                  data: widget.qrData,
                  version: QrVersions.auto,
                  size: qrSize,
                ),
              ],
            ),
          ],
        ));
  }
}
