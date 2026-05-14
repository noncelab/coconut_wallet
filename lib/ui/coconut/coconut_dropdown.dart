import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class CoconutDropdown extends StatefulWidget {
  final List<String> buttons;
  final Function onTapButton;
  final int dividerIndex;
  final Color? dividerColor;
  final Color? backgroundColor;
  final EdgeInsets margin;
  final String? selectedButton;

  const CoconutDropdown({
    super.key,
    required this.buttons,
    required this.onTapButton,
    this.dividerIndex = 0,
    this.dividerColor,
    this.backgroundColor,
    this.margin = EdgeInsets.zero,
    this.selectedButton,
  });

  @override
  State<CoconutDropdown> createState() => _CoconutDropdownState();
}

class _CoconutDropdownState extends State<CoconutDropdown> {
  late int _selectedIndex;
  final double buttonHeight = 44;
  int tapDownButtonIndex = -1;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.buttons.indexOf(widget.selectedButton ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final dividerColor = widget.dividerColor ?? colors.borderSubtle;
    final backgroundColor = widget.backgroundColor ?? colors.surface;

    return Container(
      margin: widget.margin,
      width: 152,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            spreadRadius: 1,
            blurRadius: 16,
            offset: const Offset(5, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.buttons.length, (index) {
          return _button(
            context,
            widget.buttons[index],
            index,
            dividerColor,
            backgroundColor,
            dividerHeight: widget.dividerIndex > 0 && widget.dividerIndex == index + 1 ? 5 : 1,
            isFirst: index == 0,
            isLast: index == widget.buttons.length - 1,
          );
        }),
      ),
    );
  }

  Widget _button(
    BuildContext context,
    String title,
    int index,
    Color dividerColor,
    Color backgroundColor, {
    double dividerHeight = 1,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final colors = context.coconutColors;
    final typography = context.coconutTypography;

    return Column(
      children: [
        InkWell(
          onTapDown: (_) {
            setState(() {
              tapDownButtonIndex = index;
            });
          },
          onTapCancel: () {
            setState(() {
              tapDownButtonIndex = -1;
            });
          },
          onTap: () {
            widget.onTapButton.call(index);
          },
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Container(
            width: double.maxFinite,
            height: buttonHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              borderRadius:
                  isFirst
                      ? const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))
                      : isLast
                      ? const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))
                      : null,
              color: tapDownButtonIndex == index ? colors.borderSubtle : backgroundColor,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: typography.body.copyWith(color: colors.primaryText, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                if (_selectedIndex == index) SvgPicture.asset('assets/svg/check.svg'),
              ],
            ),
          ),
        ),
        if (!isLast) Container(height: dividerHeight, color: dividerHeight == 1 ? dividerColor : colors.surfacePressed),
      ],
    );
  }
}
