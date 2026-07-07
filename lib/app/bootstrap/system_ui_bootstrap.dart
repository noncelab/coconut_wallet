import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/app/bootstrap/platform_channels.dart';
import 'package:coconut_wallet/app/bootstrap/splash_theme.dart';
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

  /// StatusBar: 화면 상단의 시간, 배터리, 신호 표시 영역
  /// Android에서만 실제로 적용되고, iOS는 무시됩니다.
  /// NavigationBar: 뒤로가기/홈/멀티태스킹 버튼 영역 (화면 최상단)
  setSystemBarColor(
    Platform.isIOS
        ? CoconutColors.black
        : appFlavor == 'mainnet'
        ? splashBackgroundColorMainnet
        : splashBackgroundColorRegtest,
  );
}
