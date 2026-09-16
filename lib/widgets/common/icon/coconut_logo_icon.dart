import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CoconutLogoIcon extends StatelessWidget {
  final double size;
  final Color? colorOverride;
  final Gradient? gradientOverride;
  final bool disableThemeGradient;

  const CoconutLogoIcon({
    super.key,
    this.size = Sizes.size60,
    this.colorOverride,
    this.gradientOverride,
    this.disableThemeGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedGradient =
        gradientOverride ??
        (AppIconPath.isMainnet && colorOverride == null && !disableThemeGradient
            ? context.coconutColors.mainnetLogoGradient
            : null);
    final resolvedColor =
        colorOverride ?? (resolvedGradient != null ? Colors.white : context.coconutColors.regtestLogo);

    final logo = SvgPicture.asset(
      AppIconPath.coconut,
      width: size,
      colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
    );

    if (resolvedGradient == null) {
      return logo;
    }

    return ShaderMask(
      shaderCallback: (bounds) => resolvedGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: logo,
    );
  }
}
