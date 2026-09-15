import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PositionedCardCloseButton extends StatelessWidget {
  static const double top = 4;
  static const double right = 6;
  static const double iconSize = 24;
  static const padding = EdgeInsets.all(8);
  static const double contentRightInset = right + iconSize + 16;

  const PositionedCardCloseButton({super.key, required this.onPressed, required this.color});

  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      child: Semantics(
        button: true,
        label: t.close,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: padding,
            child: SvgPicture.asset(
              CommonActionIconPath.closeSmall,
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
