import 'package:coconut_design_system/coconut_design_system.dart' as ds;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CoconutOptionPicker extends StatelessWidget {
  const CoconutOptionPicker({
    super.key,
    required this.onTap,
    this.text,
    this.enabled = true,
    this.label,
    this.guideText,
    this.subWidget,
    this.padding,
    this.textStyle,
    this.labelStyle,
    this.guideStyle,
    this.textColor,
    this.labelColor,
    this.iconColor,
    this.iconSize = 24,
    this.showUnderline = true,
    this.dividerColor,
    this.guideTextColor,
    this.borderRadius,
    this.coconutOptionStateEnum = ds.CoconutOptionStateEnum.normal,
    this.inlineWidgets = const [],
    this.inlineSpacing = 8,
    this.enableTextWrap = false,
    this.isExpanded = false,
  });

  final String? text;
  final String? label;
  final String? guideText;
  final Widget? subWidget;
  final VoidCallback? onTap;
  final bool enabled;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final TextStyle? labelStyle;
  final TextStyle? guideStyle;
  final Color? textColor;
  final Color? labelColor;
  final Color? iconColor;
  final double iconSize;
  final bool showUnderline;
  final Color? dividerColor;
  final Color? guideTextColor;
  final double? borderRadius;
  final ds.CoconutOptionStateEnum coconutOptionStateEnum;
  final List<Widget> inlineWidgets;
  final double inlineSpacing;
  final bool enableTextWrap;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    Color getColorByState(Color defaultColor) {
      return coconutOptionStateEnum == ds.CoconutOptionStateEnum.normal
          ? defaultColor
          : coconutOptionStateEnum == ds.CoconutOptionStateEnum.warning
          ? colors.warning
          : colors.danger;
    }

    final resolvedTextColor = enabled ? (textColor ?? colors.primaryText) : colors.secondaryText;
    final collapsedIconBaseColor = iconColor ?? colors.mutedText;
    final resolvedIconColor = getColorByState(
      enabled ? (isExpanded ? colors.primaryText : collapsedIconBaseColor) : colors.secondaryText,
    );
    final collapsedDividerColor = dividerColor ?? colors.inputPlaceholder;
    final resolvedDividerColor = getColorByState(isExpanded ? colors.primaryText : collapsedDividerColor);
    final resolvedTextStyle = textStyle ?? ds.CoconutTypography.heading4_18.setColor(resolvedTextColor);
    final resolvedGuideTextColor = getColorByState(guideTextColor ?? colors.secondaryText);
    final resolveGuideStyle = guideStyle ?? ds.CoconutTypography.caption_10.setColor(resolvedGuideTextColor);
    final resolvedLabelColor = labelColor ?? colors.secondaryText;
    final resolvedLabelStyle = labelStyle ?? ds.CoconutTypography.body3_12.setColor(resolvedLabelColor);

    final List<InlineSpan> wrappedContentSpans = [
      if (text != null) TextSpan(text: text, style: resolvedTextStyle),
      for (int index = 0; index < inlineWidgets.length; index++) ...[
        if (text != null || index > 0)
          WidgetSpan(alignment: PlaceholderAlignment.middle, child: SizedBox(width: inlineSpacing)),
        WidgetSpan(alignment: PlaceholderAlignment.middle, child: inlineWidgets[index]),
      ],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(label!, textAlign: TextAlign.start, style: resolvedLabelStyle),
          ),
        _ShrinkOnTap(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: padding ?? EdgeInsets.fromLTRB(2, label != null ? 6 : 0, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child:
                      enableTextWrap
                          ? Text.rich(TextSpan(children: wrappedContentSpans), softWrap: true)
                          : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (text != null) Text(text!, maxLines: 1, softWrap: false, style: resolvedTextStyle),
                                for (final widget in inlineWidgets) ...[SizedBox(width: inlineSpacing), widget],
                              ],
                            ),
                          ),
                ),
                const SizedBox(width: 8),
                _AnimatedChevron(isExpanded: isExpanded, color: resolvedIconColor, iconSize: iconSize),
              ],
            ),
          ),
        ),
        if (showUnderline)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 1,
            color: resolvedDividerColor,
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (coconutOptionStateEnum != ds.CoconutOptionStateEnum.normal && guideText != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, left: 2),
                  child: Align(alignment: Alignment.centerLeft, child: Text(guideText!, style: resolveGuideStyle)),
                ),
              )
            else
              Container(),
            if (subWidget != null) Padding(padding: const EdgeInsets.only(top: 4, left: 2), child: subWidget!),
          ],
        ),
      ],
    );
  }
}

class _AnimatedChevron extends StatefulWidget {
  const _AnimatedChevron({required this.isExpanded, required this.color, required this.iconSize});

  final bool isExpanded;
  final Color color;
  final double iconSize;

  @override
  State<_AnimatedChevron> createState() => _AnimatedChevronState();
}

class _AnimatedChevronState extends State<_AnimatedChevron> {
  late double _turns;

  @override
  void initState() {
    super.initState();
    _turns = widget.isExpanded ? 0.5 : 0.0;
  }

  @override
  void didUpdateWidget(covariant _AnimatedChevron oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpanded == widget.isExpanded) return;

    // Add 180deg on every toggle so the chevron keeps rotating
    // through a circular path instead of feeling like it snaps.
    _turns += 0.5;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _turns),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      builder: (context, turns, child) {
        return Transform.rotate(angle: turns * 3.141592653589793 * 2, alignment: Alignment.center, child: child);
      },
      child: SvgPicture.asset(
        'packages/coconut_design_system/assets/svg/pulldown_close.svg',
        width: widget.iconSize,
        height: widget.iconSize,
        colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
      ),
    );
  }
}

class _ShrinkOnTap extends StatefulWidget {
  const _ShrinkOnTap({required this.child, this.onTap});

  static const double _pressedScale = 0.97;
  static const Duration _duration = Duration(milliseconds: 100);

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_ShrinkOnTap> createState() => _ShrinkOnTapState();
}

class _ShrinkOnTapState extends State<_ShrinkOnTap> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? _ShrinkOnTap._pressedScale : 1.0,
        duration: _ShrinkOnTap._duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
