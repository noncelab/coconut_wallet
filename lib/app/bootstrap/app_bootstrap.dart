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
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'system_ui_bootstrap.dart';
import 'platform_channels.dart';

class AppBootstrap {
  static Future<void> initialize() async {
    Provider.debugCheckInvalidValueType = null;
    await SharedPrefsRepository().init();
    _applyPersistedTheme();

    await configureSystemUi();

    await _loadEnvironment();
    // 기본 서버 매칭(findMatching)이 NetworkType에 의존하므로 _loadEnvironment() 이후에 호출해야 한다.
    await ElectrumServerProvider().migrateLegacyCustomServerStorage();
    final analytics = await initializeAnalytics(
      useFirebase: const bool.fromEnvironment('USE_FIREBASE', defaultValue: false),
      isAndroid: Platform.isAndroid,
    );
    CoconutWalletApp.kIsFirebaseAnalyticsUsed = analytics.isFirebaseUsed;
    CoconutWalletApp.kAnalyticsService = analytics.service;
    await CoconutWalletApp.kAnalyticsService.initialize();
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

  /// Android의 저장된 OFF는 Core의 eager AnalyticsConnector도 시작하지 않는다.
  /// 다른 Firebase 제품을 추가할 때는 기본 앱 초기화가 수집을 다시 시작하지 않는지 확인해야 한다.
  @visibleForTesting
  static Future<({AnalyticsService service, bool isFirebaseUsed})> initializeAnalytics({
    required bool useFirebase,
    required bool isAndroid,
    SharedPrefsRepository? preferences,
    Future<void> Function()? initializeFirebase,
    Future<void> Function()? attachAnalytics,
    Future<void> Function()? disableAnalyticsIfActive,
    Future<void> Function(bool)? setComponentsEnabled,
    FirebaseAnalytics Function()? analyticsFactory,
  }) async {
    final prefs = preferences ?? SharedPrefsRepository();
    Logger.log('👉 Firebase 사용 여부: $useFirebase');
    if (!useFirebase) {
      return (service: AnalyticsService(null, true, sharedPrefs: prefs), isFirebaseUsed: false);
    }
    final Future<void> Function() initializeCore =
        initializeFirebase ??
        () async {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        };
    final attach = attachAnalytics ?? () => _invokeAnalyticsMethod('attachAnalytics');
    final disable = disableAnalyticsIfActive ?? () => _invokeAnalyticsMethod('disableAnalyticsIfActive');
    final createBackend = analyticsFactory ?? () => FirebaseAnalytics.instance;
    if (isAndroid) {
      final requiresAttachment = prefs.sharedPrefs.get(SharedPrefKeys.kAnalyticsCollectionEnabled) == false;
      return (
        service: AnalyticsService(
          null,
          false,
          sharedPrefs: prefs,
          setComponentsEnabled:
              setComponentsEnabled ?? (enabled) => _invokeAnalyticsMethod('setAnalyticsComponentsEnabled', enabled),
          deferredBackend: DeferredAnalyticsBackend(
            activate: () async {
              if (requiresAttachment) {
                await attach();
              } else {
                try {
                  await attach();
                } catch (e) {
                  // 보통 엔진은 이미 등록했다. OS 채널 오류만으로 SDK 상태 적용을 건너뛰지 않는다.
                  Logger.error('Analytics plugin attachment failed: ${e.runtimeType}');
                }
              }
              await initializeCore();
              return createBackend();
            },
            disableIfActive: disable,
          ),
        ),
        isFirebaseUsed: true,
      );
    }
    try {
      await initializeCore();
      return (service: AnalyticsService(createBackend(), false, sharedPrefs: prefs), isFirebaseUsed: true);
    } catch (e) {
      Logger.error('Firebase initialization failed: ${e.runtimeType}');
      return (service: AnalyticsService(null, true, sharedPrefs: prefs), isFirebaseUsed: false);
    }
  }

  static Future<void> _invokeAnalyticsMethod(String method, [Object? arguments]) async {
    await const MethodChannel(methodChannelOS).invokeMethod<void>(method, arguments);
  }
}
