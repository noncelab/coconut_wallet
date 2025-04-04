import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

class CustomUnderlinedButton extends StatefulWidget {
  final String text;
  final double fontSize;
  final double? lineHeight;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? padding;
  final Color? defaultColor;
  final Color? pressingColor;
  final bool isEnable;

  const CustomUnderlinedButton({
    super.key,
    required this.text,
    required this.onTap,
    this.fontSize = 12,
    this.lineHeight,
    this.padding,
    this.defaultColor,
    this.pressingColor,
    this.isEnable = true,
  });

  @override
  State<CustomUnderlinedButton> createState() => _CustomUnderlinedButtonState();
}

class _CustomUnderlinedButtonState extends State<CustomUnderlinedButton> {
  late bool _isPressing;

  @override
  void initState() {
    super.initState();
    _isPressing = false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!widget.isEnable) return;
        widget.onTap();
        setState(() {
          _isPressing = false;
        });
      },
      onTapDown: (details) {
        if (!widget.isEnable) return;
        setState(() {
          _isPressing = true;
        });
      },
      onTapCancel: () {
        if (!widget.isEnable) return;
        setState(() {
          _isPressing = false;
        });
      },
      child: Container(
        padding: widget.padding ?? const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: widget.isEnable
                      ? _isPressing
                          ? widget.pressingColor ?? CoconutColors.gray500
                          : widget.defaultColor ?? CoconutColors.white
                      : CoconutColors.white.withOpacity(0.2),
                  width: 0.5),
            ),
          ),
          child: Text(
            widget.text,
            style: CoconutTypography.body3_12.copyWith(
                // decoration: TextDecoration.underline, // 밑줄 설정
                fontSize: widget.fontSize,
                height: (widget.lineHeight ?? widget.fontSize) / widget.fontSize,
                color: widget.isEnable
                    ? _isPressing
                        ? widget.pressingColor ?? CoconutColors.gray500
                        : widget.defaultColor ?? CoconutColors.white
                    : CoconutColors.white.withOpacity(0.2)),
          ),
        ),
      ),
    );
  }
}
