import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class WalletBalanceSyncShimmer extends StatelessWidget {
  const WalletBalanceSyncShimmer({super.key, required this.isRefreshing, required this.child});

  final bool isRefreshing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isRefreshing) return child;

    final colors = context.coconutColors;
    return Shimmer.fromColors(
      period: const Duration(milliseconds: 1100),
      baseColor: colors.tertiaryText,
      highlightColor: Color.lerp(colors.mutedText, colors.secondaryText, 0.25)!,
      child: child,
    );
  }
}
