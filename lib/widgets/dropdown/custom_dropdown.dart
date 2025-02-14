import 'package:coconut_wallet/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

@Deprecated("CustomDropdown")
class CustomDropdown extends StatefulWidget {
  final List<String> buttons;
  final Function onTapButton;
  final int dividerIndex;
  final Color dividerColor;
  final Color backgroundColor;
  final EdgeInsets margin;
  final String? selectedButton;

  const CustomDropdown(
      {super.key,
      required this.buttons,
      required this.onTapButton,
      this.dividerIndex = 0,
      this.dividerColor = MyColors.borderGrey,
      this.backgroundColor = MyColors.shadowGray,
      this.margin = EdgeInsets.zero,
      this.selectedButton});

  @override
  State<CustomDropdown> createState() => _CustomDropdownState();
}

class _CustomDropdownState extends State<CustomDropdown> {
  late int _selectedIndex;
  final buttonHeight = 44.0;
  int tapDownButtonIndex = -1;

  @override
  void initState() {
    _selectedIndex = widget.buttons.indexOf(widget.selectedButton ?? '');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // frosted_appbar height + status bar height - margin
    return Container(
      margin: widget.margin,
      width: 152,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
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
            widget.buttons[index],
            index,
            widget.dividerColor,
            widget.backgroundColor,
            dividerHeight:
                widget.dividerIndex > 0 && widget.dividerIndex == index + 1
                    ? 5
                    : 1,
            isFirst: index == 0,
            isLast: index == widget.buttons.length - 1,
          );
        }),
      ),
    );
  }

  Widget _button(
    String title,
    int index,
    Color dividerColor,
    Color backgroundColor, {
    double dividerHeight = 1,
    bool isFirst = false,
    bool isLast = false,
  }) {
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
              borderRadius: isFirst
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16))
                  : isLast
                      ? const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16))
                      : null,
              color: tapDownButtonIndex == index
                  ? MyColors.borderGrey
                  : backgroundColor,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: CustomFonts.text.getFontFamily,
                    color: MyColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.normal,
                  ),
                ),
                if (_selectedIndex == index)
                  SvgPicture.asset('assets/svg/check.svg')
              ],
            ),
          ),
        ),
        if (!isLast)
          Container(
              height: dividerHeight,
              color: dividerHeight == 1 ? dividerColor : MyColors.nero),
      ],
    );
  }
}
