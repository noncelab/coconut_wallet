import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/app/bootstrap/localization_bootstrap.dart';
import 'package:coconut_wallet/constants/dotenv_keys.dart';
import 'package:coconut_wallet/firebase_options.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/app_icon_util.dart';
import 'package:coconut_wallet/utils/file_logger.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'system_ui_bootstrap.dart';

class AppBootstrap {
  static Future<void> initialize() async {
    await configureSystemUi();

    Provider.debugCheckInvalidValueType = null;
    await SharedPrefsRepository().init();

    await _loadEnvironment();
    await _initializeFirebase();
    await FileLogger.initialize();
    await _updateAppIconIfNeeded();

    setupPluralResolvers();
  }

  static Future<void> _loadEnvironment() async {
    const envFile = '$appFlavor.env';
    await dotenv.load(fileName: envFile);

    CoconutWalletApp.kFaucetHost = dotenv.env[DotenvKeys.apiHost] ?? '';
    CoconutWalletApp.kNetworkType = NetworkType.getNetworkType(dotenv.env[DotenvKeys.networkType]!);
    NetworkType.setNetworkType(CoconutWalletApp.kNetworkType);
  }

  static Future<void> _initializeFirebase() async {
    CoconutWalletApp.kIsFirebaseAnalyticsUsed = const bool.fromEnvironment('USE_FIREBASE', defaultValue: false);
    Logger.log('👉 Firebase 사용 여부: ${CoconutWalletApp.kIsFirebaseAnalyticsUsed}');

    if (CoconutWalletApp.kIsFirebaseAnalyticsUsed) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  }

  static Future<void> _updateAppIconIfNeeded() async {
    if (Platform.isIOS && appFlavor == 'mainnet') {
      await changeAppIcon();
    }
  }
}
