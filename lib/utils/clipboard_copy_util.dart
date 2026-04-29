import 'dart:io';

import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/main.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ClipboardCopyUtil {
  static const MethodChannel _channel = MethodChannel(methodChannelOS);

  static Future<void> copyWithToast(
    BuildContext context, {
    required String text,
    String? toastMessage,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));

    if (Platform.isAndroid) {
      try {
        final int version = await _channel.invokeMethod('getSdkVersion');

        // Android 13(API 33)부터는 시스템 클립보드 안내가 표시됨
        if (version > 31) {
          return;
        }
      } on PlatformException catch (e) {
        Logger.log("Failed to get platform version: '${e.message}'.");
      }
    }

    if (!context.mounted) return;

    final fToast = FToast()..init(context);
    final toast = MyToast.getToastWidget(toastMessage ?? t.copied);
    fToast.showToast(
      child: toast,
      gravity: ToastGravity.BOTTOM,
      toastDuration: const Duration(seconds: 2),
    );
  }
}
