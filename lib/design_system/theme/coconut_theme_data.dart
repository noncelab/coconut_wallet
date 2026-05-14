import 'package:coconut_wallet/design_system/theme/coconut_theme_extension.dart';
import 'package:flutter/material.dart';

ThemeData buildCoconutThemeData() {
  final extension = CoconutThemeExtension.dark();

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: extension.colors.background,
    extensions: [extension],
  );
}
