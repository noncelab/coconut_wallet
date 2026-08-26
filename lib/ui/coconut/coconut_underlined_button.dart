import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

class CoconutUnderlinedButton extends StatefulWidget {
  final String text;
  final TextStyle textStyle;
  final double lineWidth;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? padding;
  final Color? defaultColor;
  final Color? pressingColor;
  final bool isActive;

  CoconutUnderlinedButton({
    super.key,
    required this.text,
    TextStyle? textStyle,
    this.lineWidth = 1,
    required this.onTap,
    this.padding,
    this.defaultColor,
    this.pressingColor,
    this.isActive = true,
  }) : textStyle = textStyle ?? CoconutTypography.body2_14_Bold;

  @override
  State<CoconutUnderlinedButton> createState() => _CoconutUnderlinedButtonState();
}

class _CoconutUnderlinedButtonState extends State<CoconutUnderlinedButton> {
  bool _isPressing = false;

  @override
  Widget build(BuildContext context) {
    final color = _resolvedColor(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (!widget.isActive) return;
        widget.onTap();
        setState(() => _isPressing = false);
      },
      onTapDown: (_) {
        if (!widget.isActive) return;
        setState(() => _isPressing = true);
      },
      onTapCancel: () {
        if (!widget.isActive) return;
        setState(() => _isPressing = false);
      },
      child: Padding(
        padding: widget.padding ?? const EdgeInsets.all(4),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.text,
                textAlign: TextAlign.center,
                softWrap: true,
                style: widget.textStyle.setColor(color),
              ),
              Container(
                width: _getTextWidth(context) + 4,
                height: widget.lineWidth,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _resolvedColor(BuildContext context) {
    final colors = context.coconutColors;
    final baseColor = widget.defaultColor ?? colors.primaryText;

    if (!widget.isActive) {
      return baseColor.withValues(alpha: 0.2);
    }
    if (_isPressing) {
      return widget.pressingColor ?? baseColor.withValues(alpha: 0.5);
    }
    return baseColor;
  }

  double _getTextWidth(BuildContext context) {
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.textStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return textPainter.width;
  }
}
