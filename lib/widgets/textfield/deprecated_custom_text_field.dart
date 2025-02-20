import 'package:flutter/cupertino.dart';
import 'package:coconut_wallet/styles.dart';

@Deprecated("")
class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String placeholder;
  final TextStyle placeholderStyle;
  final TextStyle style;
  final ValueChanged<String> onChanged;
  final int? maxLines;
  final int? minLines;
  final EdgeInsetsGeometry padding;
  final bool obscureText;
  final Widget? suffix;
  final bool? valid;
  final String errorMessage;
  final OverlayVisibilityMode clearButtonMode;
  final FocusNode? focusNode;
  final int? maxLength;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.onChanged,
    this.style = Styles.body1,
    this.placeholderStyle = Styles.body2Grey,
    this.maxLines,
    this.minLines,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 20),
    this.obscureText = false,
    this.suffix,
    this.valid,
    this.errorMessage = '',
    this.clearButtonMode = OverlayVisibilityMode.never,
    this.focusNode,
    this.maxLength,
  });

  @override
  _CustomTextFieldState createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      buildTextField(),
      if (widget.errorMessage.isNotEmpty && widget.valid == false)
        Padding(
            padding: const EdgeInsets.only(left: 4, top: 8),
            child: Text(
              widget.errorMessage,
              style: const TextStyle(
                  color: MyColors.red, fontFamily: 'Pretendard', fontSize: 12),
            )),
    ]);
  }

  Stack buildTextField() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Text(
            widget.controller.text.isNotEmpty ? '' : widget.placeholder,
            style: widget.placeholderStyle,
          ),
        ),
        FocusScope(
          child: Focus(
            onFocusChange: (focus) {
              setState(() {
                isFocused = focus;
              });
            },
            child: Container(
                padding: EdgeInsets.only(
                    right: widget.clearButtonMode != OverlayVisibilityMode.never
                        ? 4
                        : 0),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isFocused
                        ? MyColors.white
                        : MyColors.transparentBlack_06,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Row(
                  children: [
                    Expanded(
                        child: CupertinoTextField(
                      controller: widget.controller,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.0),
                        color: MyColors.transparentWhite_15,
                      ),
                      textAlignVertical: TextAlignVertical.top,
                      padding: widget.padding,
                      style: widget.style,
                      onChanged: widget.onChanged,
                      maxLines: widget.maxLines,
                      minLines: widget.minLines,
                      obscureText: widget.obscureText,
                      suffix: widget.suffix,
                      clearButtonMode: widget.clearButtonMode,
                      focusNode: widget.focusNode,
                      maxLength: widget.maxLength,
                    )),
                  ],
                )),
          ),
        ),
      ],
    );
  }
}
