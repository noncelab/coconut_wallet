import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/widgets/button/copy_text_container.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeInfo extends StatefulWidget {
  final String qrData;
  final Widget? qrcodeTopWidget;

  const QrCodeInfo({super.key, required this.qrData, this.qrcodeTopWidget});

  @override
  State<QrCodeInfo> createState() => _QrCodeInfoState();
}

class _QrCodeInfoState extends State<QrCodeInfo> {
  @override
  Widget build(BuildContext context) {
    final double qrSize = MediaQuery.of(context).size.width * 275 / 375;

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.qrcodeTopWidget != null) ...[
              widget.qrcodeTopWidget!,
              CoconutLayout.spacing_400h,
            ],
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
            CoconutLayout.spacing_600h,
            CopyTextContainer(
              text: widget.qrData,
              textStyle: CoconutTypography.body2_14,
            ),
          ],
        ));
  }
}
