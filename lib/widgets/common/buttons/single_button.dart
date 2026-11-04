import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/extensions/string_extensions.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
                  ? _TitleValueRow(
                    title: titleColumn,
                    value: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(subtitle!, style: _resolvedSubtitleStyle(context)),
                    ),
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

  Widget _rightArrow(BuildContext context) =>
      Icon(Icons.keyboard_arrow_right_rounded, color: context.coconutColors.iconSecondary);
}

/// 제목과 값을 한 줄에 둔다. 다 들어가면 원래 배치 그대로다(제목은 남는 폭, 값은 제 너비, 사이 8).
/// 큰 글씨·좁은 화면에서 넘칠 때만, 제목 혼자 줄어 읽을 수 없게 되지 않도록 둘의 폭을 같은 비율로 줄인다.
/// 자연 폭은 자식의 intrinsic 폭을 쓴다. Flutter가 캐시하고 글·글꼴이 바뀌면 지우므로 그대로인 재빌드에서는 다시 재지 않는다.
class _TitleValueRow extends MultiChildRenderObjectWidget {
  _TitleValueRow({required Widget title, required Widget value}) : super(children: [title, value]);

  @override
  _RenderTitleValueRow createRenderObject(BuildContext context) => _RenderTitleValueRow(Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderTitleValueRow renderObject) {
    renderObject.textDirection = Directionality.of(context);
  }
}

class _TitleValueParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTitleValueRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TitleValueParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TitleValueParentData> {
  _RenderTitleValueRow(this._textDirection);

  static const double _gap = Sizes.size8;

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _title => firstChild!;
  RenderBox get _value => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TitleValueParentData) child.parentData = _TitleValueParentData();
  }

  /// 제목 칸 폭과 값의 최대 폭.
  (double, double) _widths(double maxWidth) {
    final title = _title.getMaxIntrinsicWidth(double.infinity);
    final value = _value.getMaxIntrinsicWidth(double.infinity);
    if (!maxWidth.isFinite) return (title, value);
    final room = math.max(0.0, maxWidth - _gap);
    if (title + value <= room) return (room - value, value);
    final titleWidth = title * room / (title + value);
    return (titleWidth, room - titleWidth);
  }

  Size _size(BoxConstraints constraints, ChildLayouter layoutChild) {
    final (titleWidth, valueWidth) = _widths(constraints.maxWidth);
    final title = layoutChild(
      _title,
      BoxConstraints(minWidth: titleWidth, maxWidth: titleWidth, maxHeight: constraints.maxHeight),
    );
    final value = layoutChild(_value, BoxConstraints(maxWidth: valueWidth, maxHeight: constraints.maxHeight));
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : titleWidth + _gap + value.width;
    return constraints.constrain(Size(width, math.max(title.height, value.height)));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => _size(constraints, ChildLayoutHelper.dryLayoutChild);

  @override
  void performLayout() {
    size = _size(constraints, ChildLayoutHelper.layoutChild);
    final ltr = _textDirection == TextDirection.ltr;
    _place(_title, ltr ? 0 : size.width - _title.size.width);
    _place(_value, ltr ? size.width - _value.size.width : 0);
  }

  void _place(RenderBox child, double x) {
    (child.parentData! as _TitleValueParentData).offset = Offset(x, (size.height - child.size.height) / 2);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _title.getMinIntrinsicWidth(height) + _gap + _value.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _title.getMaxIntrinsicWidth(height) + _gap + _value.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) {
    final (titleWidth, valueWidth) = _widths(width);
    return math.max(_title.getMinIntrinsicHeight(titleWidth), _value.getMinIntrinsicHeight(valueWidth));
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final (titleWidth, valueWidth) = _widths(width);
    return math.max(_title.getMaxIntrinsicHeight(titleWidth), _value.getMaxIntrinsicHeight(valueWidth));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
