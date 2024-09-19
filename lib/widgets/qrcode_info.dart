import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:coconut_wallet/widgets/button/small_action_button.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';

import '../styles.dart';
import '../utils/toast.dart';

class QRCodeInfo extends StatefulWidget {
  final String qrData;
  final Widget? qrcodeTopWidget;

  const QRCodeInfo({super.key, required this.qrData, this.qrcodeTopWidget});

  @override
  State<QRCodeInfo> createState() => _QRCodeInfoState();
}

class _QRCodeInfoState extends State<QRCodeInfo> {
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
                  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
                  AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
                  int androidVersion = int.parse(androidInfo.version.release);
                  if (androidVersion >= 12) {
                    return;
                  }
                }

                FToast fToast = FToast();

                fToast.init(context);
                final toast = MyToast.getToastWidget("복사 완료");
                fToast.showToast(
                    child: toast,
                    gravity: ToastGravity.BOTTOM,
                    toastDuration: const Duration(seconds: 2));
              },
              height: 38,
              width: 97,
            )
          ],
        ));
  }
}
