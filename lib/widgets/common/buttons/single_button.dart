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
/// 자연 폭은 레이아웃 때 잰다. 레이아웃은 제약·방향·글·글꼴이 바뀔 때만 다시 돌므로 그대로인 재빌드에서는 다시 재지 않는다.
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

  /// 자연 폭으로 제목 칸 폭과 값의 최대 폭을 정한다.
  (double, double) _split(double maxWidth, double title, double value) {
    if (!maxWidth.isFinite) return (title, value);
    final room = math.max(0.0, maxWidth - _gap);
    if (title + value <= room) return (room - value, value);
    final titleWidth = title * room / (title + value);
    return (titleWidth, room - titleWidth);
  }

  /// 제목·값에 줄 제약. [measure]로 한 줄 자연 크기를 잰다.
  (BoxConstraints, BoxConstraints) _childConstraints(BoxConstraints constraints, ChildLayouter measure) {
    final natural = BoxConstraints(maxHeight: constraints.maxHeight);
    final (titleWidth, valueWidth) = _split(
      constraints.maxWidth,
      measure(_title, natural).width,
      measure(_value, natural).width,
    );
    return (
      BoxConstraints(minWidth: titleWidth, maxWidth: titleWidth, maxHeight: constraints.maxHeight),
      BoxConstraints(maxWidth: valueWidth, maxHeight: constraints.maxHeight),
    );
  }

  Size _sizeFor(BoxConstraints constraints, Size title, Size value) {
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : title.width + _gap + value.width;
    return constraints.constrain(Size(width, math.max(title.height, value.height)));
  }

  // dry layout·dry baseline·intrinsic은 자식 RenderParagraph의 intrinsic 캐시를 쓴다. Flutter 3.35에서는 늦게 로드된
  // 글꼴 뒤에도 이 캐시가 갱신되지 않는다(원래 위젯도 같다). 실제 배치(performLayout)는 영향이 없다.
  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final (titleConstraints, valueConstraints) = _childConstraints(constraints, ChildLayoutHelper.dryLayoutChild);
    return _sizeFor(constraints, _title.getDryLayout(titleConstraints), _value.getDryLayout(valueConstraints));
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final (titleConstraints, valueConstraints) = _childConstraints(constraints, ChildLayoutHelper.dryLayoutChild);
    final title = _title.getDryLayout(titleConstraints);
    final value = _value.getDryLayout(valueConstraints);
    final height = _sizeFor(constraints, title, value).height;
    double? highest;
    for (final (child, childConstraints, childSize) in [
      (_title, titleConstraints, title),
      (_value, valueConstraints, value),
    ]) {
      final childBaseline = child.getDryBaseline(childConstraints, baseline);
      if (childBaseline == null) continue;
      final y = childBaseline + (height - childSize.height) / 2;
      highest = highest == null ? y : math.min(highest, y);
    }
    return highest;
  }

  @override
  void performLayout() {
    // 자연 폭은 intrinsic 값이 아니라 실제 레이아웃으로 잰다. Flutter 3.35의 RenderParagraph는 글꼴이 바뀌어도
    // intrinsic 측정을 갱신하지 않는다. 레이아웃은 제약·방향·글·글꼴이 바뀔 때만 다시 돌므로 그대로인 재빌드에서는 재지 않는다.
    final (titleConstraints, valueConstraints) = _childConstraints(constraints, ChildLayoutHelper.layoutChild);
    _title.layout(titleConstraints, parentUsesSize: true);
    _value.layout(valueConstraints, parentUsesSize: true);
    size = _sizeFor(constraints, _title.size, _value.size);
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

  (double, double) _intrinsicWidths(double width) =>
      _split(width, _title.getMaxIntrinsicWidth(double.infinity), _value.getMaxIntrinsicWidth(double.infinity));

  @override
  double computeMinIntrinsicHeight(double width) {
    final (titleWidth, valueWidth) = _intrinsicWidths(width);
    return math.max(_title.getMinIntrinsicHeight(titleWidth), _value.getMinIntrinsicHeight(valueWidth));
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final (titleWidth, valueWidth) = _intrinsicWidths(width);
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
