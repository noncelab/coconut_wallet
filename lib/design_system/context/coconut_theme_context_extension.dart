import 'package:coconut_wallet/design_system/theme/coconut_theme_extension.dart';
import 'package:coconut_wallet/design_system/tokens/coconut_colors.dart';
import 'package:coconut_wallet/design_system/tokens/coconut_radius.dart';
import 'package:coconut_wallet/design_system/tokens/coconut_spacing.dart';
import 'package:coconut_wallet/design_system/tokens/coconut_typography.dart';
import 'package:flutter/material.dart';

extension CoconutThemeContextExtension on BuildContext {
  CoconutThemeExtension get coconutTheme {
    final extension = Theme.of(this).extension<CoconutThemeExtension>();
    assert(extension != null, 'CoconutThemeExtension is not available in this BuildContext.');
    return extension!;
  }

  CoconutColors get coconutColors => coconutTheme.colors;

  CoconutTypography get coconutTypography => coconutTheme.typography;

  CoconutSpacing get coconutSpacing => coconutTheme.spacing;

  CoconutRadius get coconutRadius => coconutTheme.radius;
}
