import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/main.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';

import '../utils/toast.dart';

class QrCodeInfo extends StatefulWidget {
  final String qrData;
  final Widget? qrcodeTopWidget;

  const QrCodeInfo({super.key, required this.qrData, this.qrcodeTopWidget});

  @override
  State<QrCodeInfo> createState() => _QrCodeInfoState();
}

class _QrCodeInfoState extends State<QrCodeInfo> {
  static const MethodChannel _channel = MethodChannel(methodChannelOS);
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
            GestureDetector(
                onTap: () async {
                  Clipboard.setData(ClipboardData(text: widget.qrData)).then((value) => null);
                  if (Platform.isAndroid) {
                    try {
                      final int version = await _channel.invokeMethod('getSdkVersion');

                      // 안드로이드13 부터는 클립보드 복사 메세지가 나오기 때문에 예외 적용
                      if (version > 31) {
                        return;
                      }
                    } on PlatformException catch (e) {
                      Logger.log("Failed to get platform version: '${e.message}'.");
                    }
                  }

                  FToast fToast = FToast();

                  if (!context.mounted) return;

                  fToast.init(context);
                  final toast = MyToast.getToastWidget(t.copied);
                  fToast.showToast(
                      child: toast,
                      gravity: ToastGravity.BOTTOM,
                      toastDuration: const Duration(seconds: 2));
                },
                child: Text(widget.qrData,
                    style: CoconutTypography.body1_16_Number.setColor(CoconutColors.white),
                    textAlign: TextAlign.center)),
          ],
        ));
  }
}
