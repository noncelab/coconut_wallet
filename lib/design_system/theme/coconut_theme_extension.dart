import 'package:coconut_wallet/design_system/tokens/coconut_colors.dart';
import 'package:coconut_wallet/design_system/tokens/coconut_radius.dart';
import 'package:coconut_wallet/design_system/tokens/coconut_spacing.dart';
import 'package:coconut_wallet/design_system/tokens/coconut_typography.dart';
import 'package:flutter/material.dart';

@immutable
class CoconutThemeExtension extends ThemeExtension<CoconutThemeExtension> {
  final CoconutColors colors;
  final CoconutTypography typography;
  final CoconutSpacing spacing;
  final CoconutRadius radius;

  const CoconutThemeExtension({
    required this.colors,
    required this.typography,
    required this.spacing,
    required this.radius,
  });

  factory CoconutThemeExtension.dark() {
    return CoconutThemeExtension(
      colors: CoconutColors.dark(),
      typography: CoconutTypography.dark(),
      spacing: const CoconutSpacing.base(),
      radius: const CoconutRadius.base(),
    );
  }

  @override
  ThemeExtension<CoconutThemeExtension> copyWith({
    CoconutColors? colors,
    CoconutTypography? typography,
    CoconutSpacing? spacing,
    CoconutRadius? radius,
  }) {
    return CoconutThemeExtension(
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
      spacing: spacing ?? this.spacing,
      radius: radius ?? this.radius,
    );
  }

  @override
  ThemeExtension<CoconutThemeExtension> lerp(covariant ThemeExtension<CoconutThemeExtension>? other, double t) {
    if (other is! CoconutThemeExtension) {
      return this;
    }

    return t < 0.5 ? this : other;
  }
}
