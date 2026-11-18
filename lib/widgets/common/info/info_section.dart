import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 지갑 정보 화면의 묶음. 위 구분선, 굵은 제목, 아래 줄들
class InfoSection extends StatelessWidget {
  const InfoSection({
    super.key,
    required this.title,
    required this.children,
    this.dividerHeight = defaultDividerHeight,
  });

  static const double defaultDividerHeight = 12;

  final String title;
  final List<Widget> children;

  /// 0이면 구분선 없음
  final double dividerHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dividerHeight > 0) Container(height: dividerHeight, color: colors.divider),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(title, style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText)),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Column(children: children)),
        ],
      ),
    );
  }
}

/// 지갑 정보의 한 줄. 높이가 같고, 화살표나 [trailing]이 없으면 값이 오른쪽 끝에 붙는다.
class InfoMenuRow extends StatelessWidget {
  const InfoMenuRow({
    super.key,
    required this.title,
    this.onPressed,
    this.subWidget,
    this.rightWidget,
    this.trailing,
    this.titleTrailing,
    this.titleStyle,
    this.showArrowRight = true,
    this.indent = false,
  });

  static const double height = 52;
  static const double trailingGap = 8;

  final String title;
  final VoidCallback? onPressed;
  final Widget? subWidget;
  final Widget? rightWidget;
  final Widget? trailing;
  final Widget? titleTrailing;
  final TextStyle? titleStyle;
  final bool showArrowRight;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final row = SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(left: indent ? 28 : 12, right: 8),
        child: Row(
          children: [
            Text(title, style: titleStyle ?? CoconutTypography.body2_14.setColor(colors.primaryText)),
            if (titleTrailing != null) ...[const SizedBox(width: 2), titleTrailing!],
            CoconutLayout.spacing_200w,
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (subWidget != null)
                    Flexible(
                      child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: subWidget),
                    ),
                  if (rightWidget != null) ...[CoconutLayout.spacing_100w, rightWidget!],
                ],
              ),
            ),
            if (trailing != null || showArrowRight) ...[
              const SizedBox(width: trailingGap),
              trailing ?? const InfoRowArrow(),
            ],
          ],
        ),
      ),
    );
    if (onPressed == null) return row;
    return ShrinkAnimationButton(
      onPressed: onPressed!,
      defaultColor: Colors.transparent,
      pressedOverlayColor: colors.primaryText,
      pressedOverlayOpacity: 0.08,
      borderRadius: 12,
      child: row,
    );
  }
}

/// 지갑 정보 행의 화살표. 여백 없는 화살표라 글자 행과 오른쪽 끝이 맞는다.
class InfoRowArrow extends StatelessWidget {
  const InfoRowArrow({super.key});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      CommonNavigationIconPath.arrowRight,
      width: 7,
      height: 12,
      colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
    );
  }
}
