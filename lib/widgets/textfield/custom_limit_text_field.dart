import 'package:coconut_wallet/ui/coconut/coconut_limit_text_field.dart';
import 'package:flutter/material.dart';

/// TODO: CoconutTextField를 사용하는 방식으로 변경 검토
/// [CustomLimitTextField] : 최대입력 글자를 입력하고 TextFiled 아래에 표기하는 위젯
/// (controller.text.length/maxLength) = (1/30)
class CustomLimitTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onChanged;
  final VoidCallback onClear;
  final int maxLength;
  final Color cursorColor;
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
    this.cursorColor = Colors.white,
    this.prefix,
    this.keyboardType = TextInputType.text,
    this.placeholder = '',
    this.visibleTextLimit = true,
    this.formatInput,
  });

  @override
  Widget build(BuildContext context) {
    return CoconutLimitTextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onClear: onClear,
      maxLength: maxLength,
      cursorColor: cursorColor,
      prefix: prefix,
      keyboardType: keyboardType,
      placeholder: placeholder,
      visibleTextLimit: visibleTextLimit,
      formatInput: formatInput,
    );
  }
}
