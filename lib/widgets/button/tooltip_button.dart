import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

class TooltipButton extends StatefulWidget {
  final bool isSelected;
  final String text;
  final bool isLeft;
  final VoidCallback onTap;
  final GestureTapDownCallback onTapDown;
  final GlobalKey iconKey;
  final EdgeInsets containerMargin;
  final EdgeInsets containerPadding;
  final EdgeInsets iconPadding;

  const TooltipButton(
      {super.key,
      required this.isSelected,
      required this.text,
      required this.isLeft,
      required this.onTap,
      required this.onTapDown,
      required this.iconKey,
      this.containerMargin = const EdgeInsets.all(4),
      this.containerPadding = const EdgeInsets.symmetric(vertical: 8.0),
      this.iconPadding = const EdgeInsets.all(8.0)});

  @override
  State<TooltipButton> createState() => _TooltipButtonState();
}

class _TooltipButtonState extends State<TooltipButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: widget.containerMargin,
        padding: widget.containerPadding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: widget.isSelected ? CoconutColors.black.withOpacity(0.5) : Colors.transparent,
        ),
        child: Center(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.text,
                style: CoconutTypography.body2_14
                    .setColor(widget.isSelected ? CoconutColors.white : CoconutColors.gray500)
                    .copyWith(fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal),
              ),
              GestureDetector(
                onTap: () {
                  widget.onTap.call();
                },
                child: Container(
                  margin: widget.iconPadding,
                  color: Colors.transparent,
                  child: Icon(
                    key: widget.iconKey,
                    Icons.info_outline_rounded,
                    color: widget.isSelected ? CoconutColors.white : CoconutColors.gray500,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
