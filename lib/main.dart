import 'dart:async';
import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/dotenv_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/database_path_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:provider/provider.dart';

import 'app.dart';

const methodChannelOS = 'onl.coconut.wallet/os';

void main() {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  runZonedGuarded(() async {
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
          SystemChrome.setPreferredOrientations(
              [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
        }
      } on PlatformException catch (e) {
        Logger.log("Failed to get platform version: '${e.message}'.");
      }
    } else {
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    }
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [
        SystemUiOverlay.top,
        SystemUiOverlay.bottom,
      ],
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: CoconutColors.black, //상단바 색상
        statusBarIconBrightness: Brightness.light, //상단바 아이콘 색상
        systemNavigationBarDividerColor: CoconutColors.black, //하단바 디바이더 색상
        systemNavigationBarColor: CoconutColors.black, //하단바 색상
        systemNavigationBarIconBrightness: Brightness.light, //하단바 아이콘 색상
      ),
    );
    Provider.debugCheckInvalidValueType = null;

    await SharedPrefsRepository().init();

    try {
      // coconut 0.6 버전까지만 사용, 0.7버전부터 필요 없어짐, 사용하던 db 경로 데이터 삭제
      final dbDirectory = await getAppDocumentDirectory(paths: ['objectbox']);
      if (dbDirectory.existsSync()) {
        dbDirectory.deleteSync(recursive: true);
      }
    } catch (_) {
      // ignore
    }

    NetworkType.setNetworkType(NetworkType.regtest);

    String envFile = '$appFlavor.env';
    await dotenv.load(fileName: envFile);
    CoconutWalletApp.kElectrumHost = dotenv.env[DotenvKeys.electrumHost] ?? '';
    String? portString = dotenv.env[DotenvKeys.electrumPort];
    CoconutWalletApp.kElectrumPort = portString != null ? int.tryParse(portString) ?? 0 : 0;
    CoconutWalletApp.kElectrumIsSSL = dotenv.env[DotenvKeys.electrumIsSsl]?.toLowerCase() == 'true';
    CoconutWalletApp.kMempoolHost = dotenv.env[DotenvKeys.mempoolHost] ?? '';
    CoconutWalletApp.kFaucetHost = dotenv.env[DotenvKeys.apiHost] ?? '';
    runApp(const CoconutWalletApp());
  }, (error, stackTrace) {
    Logger.error(">>>>> runZoneGuarded error: $error");
    Logger.log('>>>>> runZoneGuarded StackTrace: $stackTrace');
  });
}
