import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/icons_util.dart';

class SvgIcon extends StatelessWidget {
  final int index;
  final int colorIndex;
  final bool enableBorder;

  const SvgIcon(
      {super.key,
      required this.index,
      this.colorIndex = -1,
      this.enableBorder = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: colorIndex == -1
            ? MyColors.defaultBackground
            : CustomColorHelper.getBackgroundColorByIndex(colorIndex),
      ),
      // 배경색 지정
      child: Padding(
        padding: const EdgeInsets.all(8.0), // 내부 여백 추가
        child: SvgPicture.asset(
          CustomIcons.getPathByIndex(index),
          width: 32,
          height: 32,
          fit: BoxFit.scaleDown,
          color: colorIndex == -1
              ? MyColors.defaultIcon
              : CustomColorHelper.getColorByIndex(colorIndex),
        ),
      ),
    );
  }
}
