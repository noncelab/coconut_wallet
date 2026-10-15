import 'package:coconut_wallet/design_system/tokens/coconut_colors.dart';
import 'package:flutter/material.dart';

@immutable
class CoconutThemeExtension extends ThemeExtension<CoconutThemeExtension> {
  final CoconutColors colors;

  const CoconutThemeExtension({required this.colors});

  factory CoconutThemeExtension.dark() {
    return CoconutThemeExtension(colors: CoconutColors.dark());
  }

  factory CoconutThemeExtension.light() {
    return CoconutThemeExtension(colors: CoconutColors.light());
  }

  factory CoconutThemeExtension.coconutTheme() {
    return CoconutThemeExtension(colors: CoconutColors.coconutTheme());
  }

  @override
  ThemeExtension<CoconutThemeExtension> copyWith({CoconutColors? colors}) {
    return CoconutThemeExtension(colors: colors ?? this.colors);
  }

  @override
  ThemeExtension<CoconutThemeExtension> lerp(covariant ThemeExtension<CoconutThemeExtension>? other, double t) {
    if (other is! CoconutThemeExtension) {
      return this;
    }

    return t < 0.5 ? this : other;
  }
}
