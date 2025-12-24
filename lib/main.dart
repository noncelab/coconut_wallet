import 'dart:async';
import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/dotenv_keys.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/firebase_options.dart';
import 'package:coconut_wallet/utils/file_logger.dart';
import 'package:coconut_wallet/utils/system_chrome_util.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:provider/provider.dart';

import 'app.dart';

const methodChannelOS = 'onl.coconut.wallet/os';
const methodChannelIcon = 'onl.coconut.wallet/app-event-icon';
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
      if (CoconutWalletApp.kIsFirebaseAnalyticsUsed) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }

      // FileLogger 초기화
      await FileLogger.initialize();

      // 앱 아이콘 변경 (iOS, Android에서만 지원)
      if (Platform.isIOS || Platform.isAndroid) {
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

/// 공통: 아래 메서드에서 startDate, endDate, iconName 수정
/// iOS: AppDelegate.swift 에서 iconName 수정
/// 25.12.24 ~ 2026.1.4 : birthday, 비트코인 생일 아이콘
Future<void> changeAppIcon() async {
  final sharedPrefs = SharedPrefsRepository();
  DateTime now = DateTime.now();
  debugPrint('🔄 changeAppIcon called at: $now');
  DateTime startDate = DateTime(2025, 12, 24);
  DateTime endDate = DateTime(2026, 1, 4);

  // 기간 내에 있는지 확인
  var isInPeriod =
      (now.isAfter(startDate.subtract(const Duration(days: 1))) && now.isBefore(endDate.add(const Duration(days: 1))));

  if (!isInPeriod) {
    // 기간이 지났으면 원래 아이콘으로 복구
    final savedDateStr = sharedPrefs.getString(SharedPrefKeys.kEventIconChangedDate);
    debugPrint('🔄 savedDateStr: $savedDateStr');
    // 저장된 날짜가 있거나, 현재 아이콘이 이벤트 아이콘으로 설정되어 있으면 기본 아이콘으로 복구
    bool shouldRestore = false;

    if (savedDateStr.isNotEmpty) {
      // 저장된 날짜가 있으면 아이콘이 변경된 상태
      shouldRestore = true;
    } else {
      // 저장된 날짜가 없어도 현재 아이콘이 이벤트 아이콘인지 확인
      try {
        const MethodChannel channel = MethodChannel(methodChannelIcon);
        final currentIconName = await channel.invokeMethod<String>('getCurrentIconName');
        if (currentIconName != null && currentIconName.isNotEmpty) {
          // 현재 이벤트 아이콘이 설정되어 있으면 복구 필요
          shouldRestore = true;
          debugPrint('🔄 저장된 날짜는 없지만 현재 이벤트 아이콘($currentIconName)이 설정되어 있음');
        }
      } catch (e) {
        debugPrint('⚠️ 현재 아이콘 확인 실패: $e');
        // 확인 실패 시에는 저장된 날짜가 없으면 복구하지 않음
      }
    }

    if (shouldRestore) {
      debugPrint('🔄 기간이 지났으므로 기본 아이콘으로 복구');
      try {
        const MethodChannel channel = MethodChannel(methodChannelIcon);
        await channel.invokeMethod('changeAppEventIcon', {'app_event_icon_change': false, 'icon_name': null});
        await sharedPrefs.deleteSharedPrefsWithKey(SharedPrefKeys.kEventIconChangedDate);
        debugPrint('✅ 기본 아이콘으로 복구 완료');
      } on PlatformException catch (e) {
        debugPrint("❌ 기본 아이콘으로 복구 실패: '${e.message}'.");
        // 에러가 발생해도 저장된 날짜는 삭제
        await sharedPrefs.deleteSharedPrefsWithKey(SharedPrefKeys.kEventIconChangedDate);
      } catch (e) {
        debugPrint("❌ Unexpected error while restoring icon: $e");
        await sharedPrefs.deleteSharedPrefsWithKey(SharedPrefKeys.kEventIconChangedDate);
      }
    }
    return;
  }

  final savedDateStr = sharedPrefs.getString(SharedPrefKeys.kEventIconChangedDate);
  if (savedDateStr.isNotEmpty) {
    try {
      final savedDate = DateTime.parse(savedDateStr);
      // 저장된 날짜가 기간 내에 있으면 이미 변경된 것으로 간주
      if (savedDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
          savedDate.isBefore(endDate.add(const Duration(days: 1)))) {
        debugPrint('🔄 이미 변경된 날짜: $savedDate, 아이콘 변경 건너뜀');
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to parse saved date: $e');
      // 파싱 실패 시 저장된 값 삭제하고 계속 진행
      await sharedPrefs.deleteSharedPrefsWithKey(SharedPrefKeys.kEventIconChangedDate);
    }
  }

  // 아이콘 변경 실행
  debugPrint('🔄 아이콘 변경 실행');
  try {
    const MethodChannel channel = MethodChannel(methodChannelIcon);
    await channel.invokeMethod('changeAppEventIcon', {'app_event_icon_change': true, 'icon_name': 'birthday'});

    // 변경 성공 시 현재 날짜 저장
    await sharedPrefs.setString(SharedPrefKeys.kEventIconChangedDate, now.toIso8601String());
    debugPrint('✅ 아이콘 변경 완료 및 날짜 저장');
  } on PlatformException catch (e) {
    debugPrint("❌ Failed to change icon: '${e.message}'.");
    debugPrint("❌ Error code: '${e.code}'.");
    debugPrint("❌ Error details: '${e.details}'.");
  } catch (e) {
    debugPrint("❌ Unexpected error: $e");
  }
}
