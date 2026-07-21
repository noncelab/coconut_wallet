import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class IconPaletteCell extends StatelessWidget {
  final int index;
  final int? colorIndex;
  final bool enableBorder;

  const IconPaletteCell({super.key, required this.index, this.colorIndex, this.enableBorder = true});

  @override
  Widget build(BuildContext context) {
    final bgColor =
        colorIndex == null
            ? context.coconutColors.iconBackgroundSubtle
            : ColorUtil.getBackgroundColorByIndex(colorIndex!);
    final iconColor = colorIndex == null ? context.coconutColors.iconPrimary : ColorUtil.getColorByIndex(colorIndex!);

    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), color: bgColor),
      // 배경색 지정
      child: Padding(
        padding: const EdgeInsets.all(8.0), // 내부 여백 추가
        child: SvgPicture.asset(
          CustomIcons.getPathByIndex(index),
          width: 32,
          height: 32,
          fit: BoxFit.scaleDown,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
      ),
    );
  }
}
