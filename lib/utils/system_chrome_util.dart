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

void updateSystemBarColor(CoconutThemeVariant variant) {
  final theme = resolveCoconutThemeExtension(variant: variant);
  SystemChrome.setSystemUIOverlayStyle(
    buildSystemBarStyle(
      backgroundColor: theme.colors.background,
      brightness: CoconutThemeController.brightnessOf(variant),
    ),
  );
}
