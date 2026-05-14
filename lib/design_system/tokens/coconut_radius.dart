import 'package:coconut_design_system/coconut_design_system.dart' as ds;
import 'package:flutter/widgets.dart';

abstract class MyBorder {
  static const double defaultRadiusValue = 24.0;
  static final BorderRadius defaultRadius = BorderRadius.circular(
    defaultRadiusValue,
  );
  static final BorderRadius boxDecorationRadius = BorderRadius.circular(28);
}

@immutable
class CoconutRadius {
  final double sm;
  final double md;
  final double lg;
  final double xl;

  const CoconutRadius({
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });

  const CoconutRadius.base()
    : sm = ds.CoconutStyles.radius_100,
      md = ds.CoconutStyles.radius_200,
      lg = ds.CoconutStyles.radius_300,
      xl = ds.CoconutStyles.radius_400;
}
