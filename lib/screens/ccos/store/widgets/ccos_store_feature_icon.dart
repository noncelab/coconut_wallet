import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 기능 아이콘을 둥근 사각형 안에 그림
class CcosStoreFeatureIcon extends StatelessWidget {
  const CcosStoreFeatureIcon({super.key, required this.iconPath, this.size = 48, this.onSurface = false});

  final String iconPath;
  final double size;
  final bool onSurface;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onSurface ? colors.surfaceButtonOnSurface : colors.surface,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: SvgPicture.asset(
        iconPath,
        width: size / 2,
        height: size / 2,
        colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
      ),
    );
  }
}
