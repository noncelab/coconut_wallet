import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PinBox extends StatelessWidget {
  final bool isSet;
  final double? size;
  final Color? pinColor;
  final Color? backgroundColor;

  const PinBox({super.key, required this.isSet, this.size, this.pinColor, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    final boxSize = size ?? 50.0;
    return SizedBox(
      width: boxSize,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: backgroundColor ?? context.coconutColors.surfaceMuted,
          ),
          child:
              isSet
                  ? Padding(
                    padding: const EdgeInsets.all(Sizes.size12),
                    child: SvgPicture.asset(
                      AppIconPath.coconut,
                      colorFilter: ColorFilter.mode(pinColor ?? context.coconutColors.primaryText, BlendMode.srcIn),
                    ),
                  )
                  : null,
        ),
      ),
    );
  }
}
