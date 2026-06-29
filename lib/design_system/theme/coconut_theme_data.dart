import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_extension.dart';
import 'package:flutter/material.dart';

enum CoconutThemeVariant { dark, ccosPreview, ccosLight }

class CoconutThemeController {
  static final ValueNotifier<CoconutThemeVariant> variantNotifier = ValueNotifier(CoconutThemeVariant.dark);

  static CoconutThemeVariant get currentVariant => variantNotifier.value;

  static bool get isPreviewEnabled => currentVariant == CoconutThemeVariant.ccosPreview;

  static bool get isLightEnabled => currentVariant == CoconutThemeVariant.ccosLight;

  static Brightness brightnessOf(CoconutThemeVariant variant) {
    switch (variant) {
      case CoconutThemeVariant.dark:
        return Brightness.dark;
      case CoconutThemeVariant.ccosPreview:
        return Brightness.light;
      case CoconutThemeVariant.ccosLight:
        return Brightness.light;
    }
  }

  static void togglePreview() {
    variantNotifier.value = isPreviewEnabled ? CoconutThemeVariant.dark : CoconutThemeVariant.ccosPreview;
  }

  static void toggleLight() {
    variantNotifier.value = isLightEnabled ? CoconutThemeVariant.dark : CoconutThemeVariant.ccosLight;
  }
}

CoconutThemeExtension resolveCoconutThemeExtension({CoconutThemeVariant? variant}) {
  switch (variant ?? CoconutThemeController.currentVariant) {
    case CoconutThemeVariant.dark:
      return CoconutThemeExtension.dark();
    case CoconutThemeVariant.ccosPreview:
      return CoconutThemeExtension.ccosPreview();
    case CoconutThemeVariant.ccosLight:
      return CoconutThemeExtension.ccosLight();
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
