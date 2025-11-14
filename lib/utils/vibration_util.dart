import 'dart:io';

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// 매우 가벼운 피드백이 필요할 때 사용 (예: 버튼 하이라이트, 토글 온/오프)
/// 사용 중: PIN 번호 입력 시, 언어 선택 시 항목 탭, 스캔 화면에서 Density 조절 시, ...
void vibrateExtraLight() {
  if (Platform.isAndroid) {
    Vibration.vibrate(duration: 10, amplitude: 170);
  } else if (Platform.isIOS) {
    HapticFeedback.lightImpact();
  }
}

/// 연속된 가벼운 피드백이 필요한 상황에 사용 (현재 사용중인 곳 없음)
void vibrateExtraLightDouble() async {
  if (Platform.isAndroid) {
    Vibration.vibrate(pattern: [0, 10, 0, 10]);
  } else if (Platform.isIOS) {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.lightImpact();
  }
}

/// 일반적인 피드백이 필요할 때 사용 (예: 일반 성공/실패 안내)
void vibrateLight() {
  if (Platform.isAndroid) {
    Vibration.vibrate(duration: 100, amplitude: 170);
  } else if (Platform.isIOS) {
    HapticFeedback.lightImpact();
  }
}

/// 강한 경고나 주의가 필요한 상황에 사용 (예: 오류 알림, 중요한 안내)
void vibrateMedium() {
  if (Platform.isAndroid) {
    Vibration.vibrate(duration: 1000);
  } else if (Platform.isIOS) {
    HapticFeedback.vibrate();
  }
}

/// 실패를 알리기 위한 피드백에 사용 (예: 지갑 추가 실패, PIN 검증 실패, ...)
void vibrateLightDouble() async {
  if (Platform.isAndroid) {
    Vibration.vibrate(pattern: [0, 100, 100, 100], amplitude: 170);
  } else if (Platform.isIOS) {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.mediumImpact();
  }
}
