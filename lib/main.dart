import 'dart:async';
import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/dotenv_keys.dart';
import 'package:coconut_wallet/utils/system_chrome_util.dart';
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
// Android Only
const splashBackgroundColorMainnet = Color(0xff1e1e1e);
const splashBackgroundColorRegtest = Color(0xff323232);

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

    setSystemBarColor(Platform.isIOS
        ? CoconutColors.black
        : appFlavor == "mainnet"
            ? splashBackgroundColorMainnet
            : splashBackgroundColorRegtest);
    Provider.debugCheckInvalidValueType = null;
    await SharedPrefsRepository().init();

    String envFile = '$appFlavor.env';
    await dotenv.load(fileName: envFile);
    CoconutWalletApp.kElectrumHost = dotenv.env[DotenvKeys.electrumHost] ?? '';
    String? portString = dotenv.env[DotenvKeys.electrumPort];
    CoconutWalletApp.kElectrumPort = portString != null ? int.tryParse(portString) ?? 0 : 0;
    CoconutWalletApp.kElectrumIsSSL = dotenv.env[DotenvKeys.electrumIsSsl]?.toLowerCase() == 'true';
    CoconutWalletApp.kMempoolHost = dotenv.env[DotenvKeys.mempoolHost] ?? '';
    CoconutWalletApp.kFaucetHost = dotenv.env[DotenvKeys.apiHost] ?? '';
    CoconutWalletApp.kDonationAddress = dotenv.env[DotenvKeys.donationAddress] ?? '';
    CoconutWalletApp.kNetworkType = NetworkType.getNetworkType(dotenv.env[DotenvKeys.networkType]!);
    NetworkType.setNetworkType(CoconutWalletApp.kNetworkType);
    runApp(const CoconutWalletApp());
  }, (error, stackTrace) {
    Logger.error(">>>>> runZoneGuarded error: $error");
    Logger.log('>>>>> runZoneGuarded StackTrace: $stackTrace');
  });
}
