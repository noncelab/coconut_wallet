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

  const PositionedCardCloseButton({super.key, required this.onPressed, required this.color, this.positionTop = top});

  final VoidCallback onPressed;
  final Color color;
  final double positionTop;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: positionTop,
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

class PositionedCardArrowButton extends StatelessWidget {
  static const double top = PositionedCardCloseButton.top;
  static const double right = PositionedCardCloseButton.right;
  static const double iconSize = PositionedCardCloseButton.iconSize;
  static const padding = PositionedCardCloseButton.padding;
  static const double contentRightInset = PositionedCardCloseButton.contentRightInset;

  const PositionedCardArrowButton({super.key, required this.onPressed, required this.color, this.positionTop = top});

  final VoidCallback onPressed;
  final Color color;
  final double positionTop;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: positionTop,
      right: right,
      child: Semantics(
        button: true,
        label: t.wallet_signer_section.view_details,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: padding,
            child: Transform.flip(
              flipX: true,
              child: SvgPicture.asset(
                CommonNavigationIconPath.arrowBack,
                width: iconSize,
                height: iconSize,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
