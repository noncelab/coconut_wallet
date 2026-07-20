import 'package:flutter/widgets.dart';

@immutable
class CoconutSpacing {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  const CoconutSpacing({required this.xs, required this.sm, required this.md, required this.lg, required this.xl});

  const CoconutSpacing.base() : xs = 4, sm = 8, md = 16, lg = 20, xl = 24;
}
