import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_extension.dart';
import 'package:flutter/cupertino.dart';

CupertinoThemeData buildAppCupertinoTheme() {
  CoconutTheme.setTheme(Brightness.dark);
  final tokens = CoconutThemeExtension.dark();

  return CupertinoThemeData(
    brightness: Brightness.dark,
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
