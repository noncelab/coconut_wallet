import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/main.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/widgets/button/small_action_button.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';

import '../styles.dart';

class QRCodeInfo extends StatefulWidget {
  final String qrData;
  final Widget? qrcodeTopWidget;

  const QRCodeInfo({super.key, required this.qrData, this.qrcodeTopWidget});

  @override
  State<QRCodeInfo> createState() => _QRCodeInfoState();
}

class _QRCodeInfoState extends State<QRCodeInfo> {
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
              const SizedBox(height: 25)
            ],
            Stack(
              children: [
                Container(
                  width: qrSize,
                  height: qrSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                ),
                QrImageView(
                  data: widget.qrData,
                  version: QrVersions.auto,
                  size: qrSize,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(widget.qrData,
                style: Styles.body1
                    .merge(const TextStyle(fontFamily: 'SpaceGrotesk')),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SmallActionButton(
              text: '복사하기',
              onPressed: () async {
                Clipboard.setData(ClipboardData(text: widget.qrData))
                    .then((value) => null);
                if (Platform.isAndroid) {
                  try {
                    final int version =
                        await _channel.invokeMethod('getSdkVersion');

                    // 안드로이드13 부터는 클립보드 복사 메세지가 나오기 때문에 예외 적용
                    if (version > 31) {
                      return;
                    }
                  } on PlatformException catch (e) {
                    Logger.log(
                        "Failed to get platform version: '${e.message}'.");
                  }
                }

                if (context.mounted) {
                  CoconutToast.showBottomToast(
                    brightness: Brightness.dark,
                    context: context,
                    text: t.toast.qr_copy,
                  );
                }
              },
              height: 38,
              width: 97,
            )
          ],
        ));
  }
}
