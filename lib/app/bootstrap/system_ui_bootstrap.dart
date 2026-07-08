import 'dart:io';

import 'package:coconut_wallet/app/bootstrap/platform_channels.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/system_chrome_util.dart';
import 'package:flutter/services.dart';

Future<void> configureSystemUi() async {
  final rootIsolateToken = RootIsolateToken.instance!;
  BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

  if (Platform.isAndroid) {
    try {
      const channel = MethodChannel(methodChannelOS);
      final int version = await channel.invokeMethod('getSdkVersion');
      if (version != 26) {
        await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      }
    } on PlatformException catch (e) {
      Logger.log("Failed to get platform version: '${e.message}'.");
    }
  } else {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  updateSystemBarColor(CoconutThemeController.currentVariant);
}
