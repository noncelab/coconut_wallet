import 'package:coconut_wallet/styles.dart';
import 'package:flutter/material.dart';

class UnderlinedButton extends StatefulWidget {
  final String text;
  final double fontSize;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? padding;
  final Color? defaultColor;
  final Color? pressingColor;
  final bool isEnable;

  const UnderlinedButton({
    super.key,
    required this.text,
    required this.onTap,
    this.fontSize = 12,
    this.padding,
    this.defaultColor,
    this.pressingColor,
    this.isEnable = true,
  });

  @override
  State<UnderlinedButton> createState() => _UnderlinedButtonState();
}

class _UnderlinedButtonState extends State<UnderlinedButton> {
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
        child: Text(
          widget.text,
          style: TextStyle(
            decoration: TextDecoration.underline, // 밑줄 설정
            fontSize: widget.fontSize,
            fontFamily: 'Pretendard',
            color: widget.isEnable
                ? _isPressing
                    ? widget.pressingColor ?? MyColors.transparentWhite_40
                    : widget.defaultColor ?? MyColors.white
                : MyColors.transparentWhite_20,
          ),
        ),
      ),
    );
  }
}