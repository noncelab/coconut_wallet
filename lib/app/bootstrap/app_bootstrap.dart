import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/app/bootstrap/localization_bootstrap.dart';
import 'package:coconut_wallet/constants/dotenv_keys.dart';
import 'package:coconut_wallet/firebase_options.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/providers/preferences/electrum_server_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'system_ui_bootstrap.dart';

class AppBootstrap {
  static Future<void> initialize() async {
    Provider.debugCheckInvalidValueType = null;
    await SharedPrefsRepository().init();
    _applyPersistedTheme();

    await configureSystemUi();

    await _loadEnvironment();
    // 기본 서버 매칭(findMatching)이 NetworkType에 의존하므로 _loadEnvironment() 이후에 호출해야 한다.
    await ElectrumServerProvider().migrateLegacyCustomServerStorage();
    await _initializeFirebase();
    await deleteLegacyDebugLog();
    applyPersistedLocale();
    setupPluralResolvers();
  }

  /// 로그 뷰어와 함께 없앤 디버그 로그(`debug_log.txt`)가 업데이트한 기기에 남아 있으면 지운다.
  @visibleForTesting
  static Future<void> deleteLegacyDebugLog() async {
    try {
      final file = File('${(await getApplicationDocumentsDirectory()).path}/debug_log.txt');
      if (await file.exists()) await file.delete();
    } catch (e) {
      Logger.error('AppBootstrap: legacy debug log cleanup failed: ${e.runtimeType}');
    }
  }

  static void _applyPersistedTheme() {
    final stored = SharedPrefsRepository().getString(SharedPrefKeys.kThemeVariant);
    final variant = CoconutThemeVariant.values.firstWhere(
      (e) => e.name == stored,
      orElse: () => CoconutThemeVariant.dark,
    );
    CoconutThemeController.variantNotifier.value = variant;
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
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } catch (e) {
        Logger.error('Firebase initialization failed: $e');
        CoconutWalletApp.kIsFirebaseAnalyticsUsed = false;
      }
    }
  }
}
