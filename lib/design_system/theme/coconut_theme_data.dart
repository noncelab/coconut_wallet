import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_extension.dart';
import 'package:flutter/material.dart';

enum CoconutThemeVariant { dark, light, coconutPulp }

class CoconutThemeController {
  static final ValueNotifier<CoconutThemeVariant> variantNotifier = ValueNotifier(CoconutThemeVariant.dark);

  static CoconutThemeVariant get currentVariant => variantNotifier.value;

  static bool get isLightEnabled => currentVariant == CoconutThemeVariant.light;

  static Brightness brightnessOf(CoconutThemeVariant variant) {
    switch (variant) {
      case CoconutThemeVariant.dark:
        return Brightness.dark;
      case CoconutThemeVariant.light:
      case CoconutThemeVariant.coconutPulp:
        return Brightness.light;
    }
  }

  static void toggleLight() {
    variantNotifier.value = isLightEnabled ? CoconutThemeVariant.dark : CoconutThemeVariant.light;
  }
}

CoconutThemeExtension resolveCoconutThemeExtension({CoconutThemeVariant? variant}) {
  switch (variant ?? CoconutThemeController.currentVariant) {
    case CoconutThemeVariant.dark:
      return CoconutThemeExtension.dark();
    case CoconutThemeVariant.light:
      return CoconutThemeExtension.light();
    case CoconutThemeVariant.coconutPulp:
      return CoconutThemeExtension.coconutPulp();
  }
}

ThemeData buildCoconutThemeData({CoconutThemeVariant? variant}) {
  final resolvedVariant = variant ?? CoconutThemeController.currentVariant;
  final extension = resolveCoconutThemeExtension(variant: resolvedVariant);
  final brightness = CoconutThemeController.brightnessOf(resolvedVariant);

  CoconutTheme.setTheme(brightness);

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: extension.colors.background,
    extensions: [extension],
  );
}
