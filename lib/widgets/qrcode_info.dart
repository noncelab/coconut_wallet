import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/widgets/adaptive_qr_image.dart';
import 'package:coconut_wallet/widgets/button/copy_text_container.dart';
import 'package:flutter/material.dart';

class QrCodeInfo extends StatefulWidget {
  final String qrData;
  final String? displayText;
  final Widget? qrcodeTopWidget;
  final bool isAddress;
  final ImageProvider? embedImage;
  final GlobalKey? qrCaptureKey;
  final TextStyle? textStyle;

  const QrCodeInfo({
    super.key,
    required this.qrData,
    this.displayText,
    this.qrcodeTopWidget,
    this.isAddress = false,
    this.embedImage,
    this.qrCaptureKey,
    this.textStyle,
  });

  @override
  State<QrCodeInfo> createState() => _QrCodeInfoState();
}

class _QrCodeInfoState extends State<QrCodeInfo> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.qrcodeTopWidget != null) ...[widget.qrcodeTopWidget!, CoconutLayout.spacing_400h],
        RepaintBoundary(
          key: widget.qrCaptureKey,
          child: AdaptiveQrImage(qrData: widget.qrData, embedImage: widget.embedImage),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CopyTextContainer(
            text: widget.displayText ?? widget.qrData,
            copyText: widget.qrData,
            textStyle: widget.textStyle ?? CoconutTypography.body2_14,
            isAddress: widget.isAddress,
          ),
        ),
      ],
    );
  }
}
