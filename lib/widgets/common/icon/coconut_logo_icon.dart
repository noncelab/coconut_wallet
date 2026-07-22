import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CoconutLogoIcon extends StatelessWidget {
  final double size;

  const CoconutLogoIcon({super.key, this.size = Sizes.size60});

  @override
  Widget build(BuildContext context) {
    final logo = SvgPicture.asset(
      AppIconPath.coconut,
      width: size,
      colorFilter: AppIconPath.isMainnet ? null : ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
    );

    if (!AppIconPath.isMainnet) {
      return logo;
    }

    return ShaderMask(
      shaderCallback: (bounds) => context.coconutColors.mainnetLogoGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: logo,
    );
  }
}
