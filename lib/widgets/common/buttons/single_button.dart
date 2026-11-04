import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/extensions/string_extensions.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';

enum SingleButtonPosition { none, top, middle, bottom }

extension SingleButtonBorderRadiusExtension on SingleButtonPosition {
  BorderRadius get radius {
    switch (this) {
      case SingleButtonPosition.none:
        return BorderRadius.circular(Sizes.size24);
      case SingleButtonPosition.top:
        return const BorderRadius.vertical(top: Radius.circular(Sizes.size24));
      case SingleButtonPosition.middle:
        return BorderRadius.zero;
      case SingleButtonPosition.bottom:
        return const BorderRadius.vertical(bottom: Radius.circular(Sizes.size24));
    }
  }

  EdgeInsets get padding {
    switch (this) {
      case SingleButtonPosition.none:
        return const EdgeInsets.symmetric(horizontal: Sizes.size20, vertical: Sizes.size24);
      case SingleButtonPosition.top:
        return const EdgeInsets.only(left: Sizes.size20, right: Sizes.size20, top: Sizes.size24, bottom: Sizes.size20);
      case SingleButtonPosition.middle:
        return const EdgeInsets.all(Sizes.size20);
      case SingleButtonPosition.bottom:
        return const EdgeInsets.only(left: Sizes.size20, right: Sizes.size20, top: Sizes.size20, bottom: Sizes.size24);
    }
  }
}

class SingleButton extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? description;
  final VoidCallback? onPressed;
  final Widget? rightElement;
  final bool showRightArrowWithRightElement;
  final Widget? leftElement;
  final SingleButtonPosition buttonPosition;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Color? backgroundColor;
  final double? betweenGap;
  final EdgeInsets? customPadding;
  final bool enableShrinkAnim;
  final bool isVerticalSubtitle;
  final double animationEndValue;
  final bool showNotificationDot;

  const SingleButton({
    super.key,
    required this.title,
    this.subtitle,
    this.description,
    this.onPressed,
    this.rightElement,
    this.showRightArrowWithRightElement = false,
    this.leftElement,
    this.buttonPosition = SingleButtonPosition.none,
    this.titleStyle,
    this.subtitleStyle,
    this.backgroundColor,
    this.betweenGap = 0,
    this.customPadding,
    this.enableShrinkAnim = false,
    this.isVerticalSubtitle = false,
    this.animationEndValue = 0.95,
    this.showNotificationDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final resolvedBackgroundColor = backgroundColor ?? colors.surface;
    final buttonContent = _buildButtonContent(context);

    return enableShrinkAnim
        ? ShrinkAnimationButton(
          onPressed: onPressed ?? () {},
          defaultColor: resolvedBackgroundColor,
          pressedOverlayColor: colors.surfacePressOverlay,
          borderRadius: 24,
          animationEndValue: animationEndValue,
          child: Container(
            decoration: BoxDecoration(borderRadius: buttonPosition.radius),
            padding: getPadding(),
            child: buttonContent,
          ),
        )
        : GestureDetector(
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(color: resolvedBackgroundColor, borderRadius: buttonPosition.radius),
            padding: getPadding(),
            child: buttonContent,
          ),
        );
  }

  /// padding을 계산하는 메서드 - 하위 클래스에서 오버라이드 가능
  EdgeInsets getPadding() {
    return customPadding ?? buttonPosition.padding;
  }

  TextStyle _resolvedSubtitleStyle(BuildContext context) {
    final baseStyle =
        subtitleStyle != null
            ? subtitle != null && subtitle!.containsCJK
                ? subtitleStyle!.copyWith(height: 1.3)
                : subtitleStyle!
            : subtitle != null && subtitle!.containsCJK
            ? CoconutTypography.body3_12.copyWith(height: 1.3)
            : CoconutTypography.body3_12_Number;
    return baseStyle.setColor(subtitleStyle?.color ?? context.coconutColors.tertiaryText);
  }

  Widget _buildButtonContent(BuildContext context) {
    final resolvedTitleStyle =
        titleStyle ?? CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText);
    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(title, style: resolvedTitleStyle)),
            if (showNotificationDot)
              Positioned(
                top: -1,
                right: -8,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: CoconutColors.hotPink, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
        if (isVerticalSubtitle) ...{
          SizedBox(height: betweenGap),
          FittedBox(fit: BoxFit.scaleDown, child: Text(subtitle!, style: _resolvedSubtitleStyle(context))),
        },
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leftElement != null) ...{Container(child: leftElement), CoconutLayout.spacing_400w},
        Expanded(
          child:
              subtitle != null && !isVerticalSubtitle
                  ? LayoutBuilder(
                    builder:
                        (context, constraints) =>
                            _titleAndValue(context, constraints.maxWidth, titleColumn, resolvedTitleStyle),
                  )
                  : titleColumn,
        ),
        if (rightElement != null) ...[
          rightElement!,
          if (showRightArrowWithRightElement) ...[CoconutLayout.spacing_200w, _rightArrow(context)],
        ] else
          _rightArrow(context),
      ],
    );
  }

  /// 제목과 값이 한 줄에 들어가면 원래 배치 그대로다(제목은 남는 폭, 값은 제 너비, 사이 8).
  /// 큰 글씨·좁은 화면에서 넘칠 때만 제목 혼자 줄어들어 읽을 수 없게 되지 않도록 둘을 같은 비율로 줄인다.
  Widget _titleAndValue(BuildContext context, double maxWidth, Widget titleColumn, TextStyle titleStyle) {
    final valueStyle = _resolvedSubtitleStyle(context);
    final value = FittedBox(fit: BoxFit.scaleDown, child: Text(subtitle!, style: valueStyle));
    final titleWidth = _naturalWidth(context, title, titleStyle);
    final valueWidth = _naturalWidth(context, subtitle!, valueStyle);
    final room = maxWidth - Sizes.size8;
    if (titleWidth + valueWidth <= room) {
      return Row(children: [Expanded(child: titleColumn), CoconutLayout.spacing_200w, value]);
    }
    return Row(
      children: [
        SizedBox(width: titleWidth * room / (titleWidth + valueWidth), child: titleColumn),
        CoconutLayout.spacing_200w,
        Expanded(child: value),
      ],
    );
  }

  /// Text가 FittedBox 안에서 한 줄로 그려질 때의 너비. Text와 같은 스타일 병합·글자 배율·굵은 글씨를 따른다.
  static double _naturalWidth(BuildContext context, String text, TextStyle style) {
    var effective = DefaultTextStyle.of(context).style.merge(style);
    if (MediaQuery.boldTextOf(context)) effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
    final painter = TextPainter(
      text: TextSpan(text: text, style: effective),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  Widget _rightArrow(BuildContext context) =>
      Icon(Icons.keyboard_arrow_right_rounded, color: context.coconutColors.iconSecondary);
}
