import 'dart:io';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:flutter/services.dart';

/// StatusBar: 화면 상단의 시간, 배터리, 신호 표시 영역
/// Android에서만 실제로 적용되고, iOS는 무시됩니다.
/// NavigationBar: 뒤로가기/홈/멀티태스킹 버튼 영역 (화면 최상단)
void updateSystemBarColor(CoconutThemeVariant variant) {
  if (Platform.isIOS) return;
  final theme = resolveCoconutThemeExtension(variant: variant);
  final isLight = CoconutThemeController.brightnessOf(variant) == Brightness.light;
  setSystemBarColor(theme.colors.background, brightness: isLight ? Brightness.dark : Brightness.light);
}

void setSystemBarColor(Color barColor, {Brightness brightness = Brightness.light}) {
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: barColor, //상단바 색상
      statusBarIconBrightness: brightness, //상단바 아이콘 색상
      systemNavigationBarDividerColor: barColor, //하단바 디바이더 색상
      systemNavigationBarColor: barColor, //하단바 색상
      systemNavigationBarIconBrightness: brightness, //하단바 아이콘 색상
    ),
  );
}
