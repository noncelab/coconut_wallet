import 'package:coconut_wallet/design_system/tokens/coconut_colors.dart';
import 'package:coconut_wallet/design_system/tokens/wallet_health_colors.dart';
import 'package:flutter/material.dart';

@immutable
class CoconutThemeExtension extends ThemeExtension<CoconutThemeExtension> {
  final CoconutColors colors;
  final WalletHealthColors walletHealth;

  const CoconutThemeExtension({required this.colors, this.walletHealth = WalletHealthColors.base});

  factory CoconutThemeExtension.dark() {
    return CoconutThemeExtension(colors: CoconutColors.dark(), walletHealth: WalletHealthColors.dark);
  }

  factory CoconutThemeExtension.light() {
    return CoconutThemeExtension(colors: CoconutColors.light());
  }

  factory CoconutThemeExtension.coconutTheme() {
    return CoconutThemeExtension(colors: CoconutColors.coconutTheme());
  }

  @override
  ThemeExtension<CoconutThemeExtension> copyWith({CoconutColors? colors, WalletHealthColors? walletHealth}) {
    return CoconutThemeExtension(colors: colors ?? this.colors, walletHealth: walletHealth ?? this.walletHealth);
  }

  @override
  ThemeExtension<CoconutThemeExtension> lerp(covariant ThemeExtension<CoconutThemeExtension>? other, double t) {
    if (other is! CoconutThemeExtension) {
      return this;
    }

    return CoconutThemeExtension(
      colors: CoconutColors.lerp(colors, other.colors, t),
      walletHealth: t < 0.5 ? walletHealth : other.walletHealth,
    );
  }
}
