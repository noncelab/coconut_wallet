import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:flutter/cupertino.dart';

CupertinoThemeData buildAppCupertinoTheme({CoconutThemeVariant? variant}) {
  final resolvedVariant = variant ?? CoconutThemeController.currentVariant;
  final brightness = CoconutThemeController.brightnessOf(resolvedVariant);
  final tokens = resolveCoconutThemeExtension(variant: resolvedVariant);

  CoconutTheme.setTheme(brightness);

  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: tokens.colors.primary,
    scaffoldBackgroundColor: tokens.colors.background,
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: tokens.colors.primaryText,
      ),
      navTitleTextStyle: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: tokens.colors.primaryText,
      ),
      primaryColor: tokens.colors.primaryText,
      actionTextStyle: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: tokens.colors.primaryText,
      ),
    ),
    barBackgroundColor: tokens.colors.background,
  );
}
