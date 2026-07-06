import 'dart:math' as math;
import 'package:coconut_wallet/design_system/tokens/coconut_colors.dart';
import 'package:coconut_wallet/design_system/tokens/coconut_radius.dart';
import 'package:flutter/material.dart';

export 'package:coconut_wallet/design_system/tokens/coconut_colors.dart';
export 'package:coconut_wallet/design_system/tokens/coconut_radius.dart';
export 'package:coconut_wallet/design_system/tokens/coconut_typography.dart';

/// Legacy compatibility layer kept temporarily during Phase 0A migration.
///
/// New or migrated UI code should prefer semantic tokens and `ui/coconut/**`
/// primitives instead of adding new dependencies here.

class Paddings {
  static const EdgeInsets container = EdgeInsets.symmetric(horizontal: 10, vertical: 20);
  static const EdgeInsets widgetContainer = EdgeInsets.symmetric(horizontal: 20, vertical: 16);
}

class BoxDecorations {
  static BorderRadius boxDecorationRadius = BorderRadius.circular(8);

  static BoxDecoration boxDecoration = BoxDecoration(
    borderRadius: MyBorder.boxDecorationRadius,
    color: MyColors.transparentWhite_06,
  );

  static LinearGradient getMultisigLinearGradient(List<Color> colors) {
    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      transform: const GradientRotation(math.pi / 10),
    );
  }
}
