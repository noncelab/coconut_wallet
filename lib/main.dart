import 'dart:async';
import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/dotenv_keys.dart';
//import 'package:coconut_wallet/firebase_options.dart';
import 'package:coconut_wallet/utils/file_logger.dart';
import 'package:coconut_wallet/utils/system_chrome_util.dart';
//import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/app_icon_util.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:provider/provider.dart';

import 'app.dart';

const methodChannelOS = 'onl.coconut.wallet/os';
// Android Only
const splashBackgroundColorMainnet = Color(0xff1e1e1e);
const splashBackgroundColorRegtest = Color(0xff323232);

void main() {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // 예외를 완전히 무시하는 설정
  FlutterError.onError = (FlutterErrorDetails details) {
    Logger.error("Flutter Error (무시됨): ${details.exception}");
    Logger.log("Stack trace: ${details.stack}");
  };

  runZonedGuarded(
    () async {
      // This app is designed only to work vertically, so we limit
      // orientations to portrait up and down.
      WidgetsFlutterBinding.ensureInitialized();
      final RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
      if (Platform.isAndroid) {
        try {
          const MethodChannel channel = MethodChannel(methodChannelOS);

          final int version = await channel.invokeMethod('getSdkVersion');
          if (version != 26) {
            SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
          }
        } on PlatformException catch (e) {
          Logger.log("Failed to get platform version: '${e.message}'.");
        }
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      }
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );

      setSystemBarColor(
        Platform.isIOS
            ? CoconutColors.black
            : appFlavor == "mainnet"
            ? splashBackgroundColorMainnet
            : splashBackgroundColorRegtest,
      );
      Provider.debugCheckInvalidValueType = null;
      await SharedPrefsRepository().init();

      String envFile = '$appFlavor.env';
      await dotenv.load(fileName: envFile);

      // Faucet - regtest-only
      CoconutWalletApp.kFaucetHost = dotenv.env[DotenvKeys.apiHost] ?? '';

      // Donation
      CoconutWalletApp.kDonationAddress = dotenv.env[DotenvKeys.donationAddress] ?? '';

      // Mainnet, Regtest 등 네트워크 타입 설정
      CoconutWalletApp.kNetworkType = NetworkType.getNetworkType(dotenv.env[DotenvKeys.networkType]!);
      NetworkType.setNetworkType(CoconutWalletApp.kNetworkType);

      // Firebase
      CoconutWalletApp.kIsFirebaseAnalyticsUsed = const bool.fromEnvironment('USE_FIREBASE', defaultValue: false);
      Logger.log('👉 Firebase 사용 여부: ${CoconutWalletApp.kIsFirebaseAnalyticsUsed}');
      // if (CoconutWalletApp.kIsFirebaseAnalyticsUsed) {
      //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      // }

      // FileLogger 초기화
      await FileLogger.initialize();

      // 앱 아이콘 변경
      // - iOS: 앱 실행 시점에 한 번 실행
      // - Android: 앱 아이콘 수정 후 재배포
      if (Platform.isIOS && appFlavor == "mainnet") {
        await changeAppIcon();
      }

      runApp(const CoconutWalletApp());
    },
    (error, stackTrace) {
      Logger.error(">>>>> runZoneGuarded error: $error");
      Logger.log('>>>>> runZoneGuarded StackTrace: $stackTrace');
    },
  );
}
