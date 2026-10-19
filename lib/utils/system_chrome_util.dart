import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:flutter/services.dart';

SystemUiOverlayStyle buildSystemBarStyle({required Color backgroundColor, required Brightness brightness}) {
  final iconBrightness = brightness == Brightness.light ? Brightness.dark : Brightness.light;
  return SystemUiOverlayStyle(
    statusBarColor: const Color(0x00000000),
    statusBarBrightness: brightness,
    statusBarIconBrightness: iconBrightness,
    systemNavigationBarDividerColor: backgroundColor,
    systemNavigationBarColor: backgroundColor,
    systemNavigationBarIconBrightness: iconBrightness,
  );
}

/// StatusBar: 화면 상단의 시간, 배터리, 신호 표시 영역
/// iOS는 배경 밝기, Android는 아이콘 밝기로 상태 표시줄 대비를 지정합니다.
/// NavigationBar: 뒤로가기/홈/멀티태스킹 버튼 영역 (화면 최상단)
void updateSystemBarColor(CoconutThemeVariant variant) {
  final theme = resolveCoconutThemeExtension(variant: variant);
  SystemChrome.setSystemUIOverlayStyle(
    buildSystemBarStyle(
      backgroundColor: theme.colors.background,
      brightness: CoconutThemeController.brightnessOf(variant),
    ),
  );
}
