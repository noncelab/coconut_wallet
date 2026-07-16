import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// TODO: CoconutTextField를 사용하는 방식으로 변경 검토
/// [CustomLimitTextField] : 최대입력 글자를 입력하고 TextFiled 아래에 표기하는 위젯
/// (controller.text.length/maxLength) = (1/30)
class CustomLimitTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onChanged;
  final VoidCallback onClear;
  final int maxLength;
  final Color? cursorColor;
  final Widget? prefix;
  final TextInputType keyboardType;
  final String placeholder;
  final bool visibleTextLimit;
  final String Function(String)? formatInput;

  const CustomLimitTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    this.maxLength = 30,
    this.cursorColor,
    this.prefix,
    this.keyboardType = TextInputType.text,
    this.placeholder = '',
    this.visibleTextLimit = true,
    this.formatInput,
  });

  @override
  Widget build(BuildContext context) {
    return CoconutTextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      maxLength: maxLength,
      cursorColor: cursorColor ?? context.coconutColors.primary,
      activeColor: context.coconutColors.primary,
      prefix: prefix,
      textInputType: keyboardType,
      placeholderText: placeholder,
      isLengthVisible: visibleTextLimit,
      placeholderColor: context.coconutColors.inputPlaceholder,
      borderColor: context.coconutColors.inputBorder,
      backgroundColor: context.coconutColors.inputSurface,
      height: 48,
      padding: EdgeInsets.fromLTRB(prefix != null ? 0 : 16, 14, 16, 14),
      suffix:
          controller.text.isNotEmpty
              ? GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                  child: SvgPicture.asset(
                    'assets/svg/text-field-clear.svg',
                    colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
                    width: 15,
                    height: 15,
                  ),
                ),
              )
              : null,
      textInputFormatter:
          formatInput == null
              ? null
              : [
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final formatted = formatInput!(newValue.text);
                  return TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }),
              ],
    );
  }
}
