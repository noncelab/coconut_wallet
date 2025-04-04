import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';

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
          color: widget.isSelected ? MyColors.transparentBlack_50 : Colors.transparent,
        ),
        child: Center(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.text,
                style: Styles.label.merge(
                  TextStyle(
                    color: widget.isSelected ? MyColors.white : MyColors.transparentWhite_40,
                    fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              GestureDetector(
                onTapDown: widget.onTapDown,
                child: Container(
                  padding: widget.iconPadding,
                  color: Colors.transparent,
                  child: Icon(
                    key: widget.iconKey,
                    Icons.info_outline_rounded,
                    color: widget.isSelected ? MyColors.white : MyColors.transparentWhite_40,
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
