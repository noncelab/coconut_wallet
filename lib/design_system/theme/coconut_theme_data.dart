import 'package:coconut_wallet/design_system/theme/coconut_theme_extension.dart';
import 'package:flutter/material.dart';

enum CoconutThemeVariant { dark, ccosPreview }

class CoconutThemeController {
  static final ValueNotifier<CoconutThemeVariant> variantNotifier = ValueNotifier(CoconutThemeVariant.dark);

  static CoconutThemeVariant get currentVariant => variantNotifier.value;

  static bool get isPreviewEnabled => currentVariant == CoconutThemeVariant.ccosPreview;

  static void togglePreview() {
    variantNotifier.value = isPreviewEnabled ? CoconutThemeVariant.dark : CoconutThemeVariant.ccosPreview;
  }
}

CoconutThemeExtension resolveCoconutThemeExtension({CoconutThemeVariant? variant}) {
  switch (variant ?? CoconutThemeController.currentVariant) {
    case CoconutThemeVariant.dark:
      return CoconutThemeExtension.dark();
    case CoconutThemeVariant.ccosPreview:
      return CoconutThemeExtension.ccosPreview();
  }
}

ThemeData buildCoconutThemeData({CoconutThemeVariant? variant}) {
  final extension = resolveCoconutThemeExtension(variant: variant);

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: extension.colors.background,
    extensions: [extension],
  );
}
