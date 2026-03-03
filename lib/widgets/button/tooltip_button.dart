import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

class TooltipIconAction {
  final Widget icon;
  final VoidCallback onTap;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final Key? key;

  const TooltipIconAction({required this.icon, required this.onTap, this.margin, this.padding, this.key});
}

typedef DefaultIconBuilder = Widget Function(bool isPressed);

class TooltipButton extends StatefulWidget {
  final bool isSelected;
  final String text;
  final TextStyle? textStyle;
  final TextStyle? pressedTextStyle;
  final VoidCallback onTap;
  final GlobalKey? iconKey;
  final EdgeInsets containerMargin;
  final EdgeInsets containerPadding;
  final EdgeInsets? iconPadding;
  final EdgeInsets? iconMargin;
  final DefaultIconBuilder? defaultIconBuilder;
  final List<TooltipIconAction>? extraIcons;

  const TooltipButton({
    super.key,
    required this.isSelected,
    required this.text,
    this.textStyle,
    this.pressedTextStyle,
    required this.onTap,
    this.iconKey,
    this.containerMargin = const EdgeInsets.all(4),
    this.containerPadding = const EdgeInsets.symmetric(vertical: 8.0),
    this.iconPadding,
    this.iconMargin,
    this.defaultIconBuilder,
    this.extraIcons,
  });

  @override
  State<TooltipButton> createState() => _TooltipButtonState();
}

class _TooltipButtonState extends State<TooltipButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle =
        widget.textStyle ??
        CoconutTypography.body2_14
            .setColor(widget.isSelected ? CoconutColors.white : CoconutColors.gray500)
            .copyWith(fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: Container(
        margin: widget.containerMargin,
        padding: widget.containerPadding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: widget.isSelected ? CoconutColors.black.withValues(alpha: 0.5) : Colors.transparent,
        ),
        child: Center(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.text,
                style: _isPressed ? (widget.pressedTextStyle ?? defaultTextStyle) : defaultTextStyle,
              ),
              Container(
                key: widget.iconKey,
                margin: widget.iconMargin,
                padding: widget.iconPadding,
                color: Colors.transparent,
                child: widget.defaultIconBuilder != null
                    ? widget.defaultIconBuilder!(_isPressed)
                    : Icon(
                        Icons.info_outline_rounded,
                        color: widget.isSelected ? CoconutColors.white : CoconutColors.gray500,
                        size: 18,
                      ),
              ),
              if (widget.extraIcons != null)
                for (final action in widget.extraIcons!)
                  GestureDetector(
                    key: action.key,
                    behavior: HitTestBehavior.opaque,
                    onTap: action.onTap,
                    child: Container(
                      margin: action.margin ?? const EdgeInsets.only(left: 4),
                      padding: action.padding,
                      child: action.icon,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
