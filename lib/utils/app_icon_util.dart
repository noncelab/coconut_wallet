import 'dart:io';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const methodChannelIcon = 'onl.coconut.wallet/app-event-icon';

/// 공통: 아래 메서드에서 startDate, endDate, iconName 수정
/// [iOS]
/// info.plist 수정, Runner/Assets.xcassets에 파일 추가
/// > 이후 AppDelegate.swift 에서 iconName 수정
/// [Android]
/// app/src/main/res/ 해상도 별 파일 추가 (ic_launcher_event, ic_launcher_event_round)
/// AndroidManifest에서 android:icon="@mipmap/ic_launcher_event" 설정
/// 안드로이드는 앱 재배포가 필요함

/// History
/// 26.1.1 ~ 26.1.31 : birthday, 비트코인 생일 아이콘
Future<void> changeAppIcon() async {
  // iOS에서만 동작
  if (!Platform.isIOS) return;

  final sharedPrefs = SharedPrefsRepository();
  final DateTime now = DateTime.now();
  debugPrint('🔄 changeAppIcon called at: $now (platform: ${Platform.operatingSystem})');

  final DateTime startDate = DateTime(2026, 1, 1);
  final DateTime endDate = DateTime(2026, 1, 31);

  // 기간 내에 있는지 확인
  final bool isInPeriod =
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
        final String? currentIconName = await channel.invokeMethod<String>('getCurrentIconName');
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

  final String savedDateStr = sharedPrefs.getString(SharedPrefKeys.kEventIconChangedDate);
  if (savedDateStr.isNotEmpty) {
    try {
      final DateTime savedDate = DateTime.parse(savedDateStr);
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
