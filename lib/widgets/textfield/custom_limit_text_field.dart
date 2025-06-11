import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  final Color cursorColor;
  final Widget? prefix;
  final TextInputType keyboardType;
  final String placeholder;
  final bool visibleTextLimit;
  final String Function(String)? formatInput;

  const CustomLimitTextField(
      {super.key,
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
      this.formatInput});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min, // 컨텐츠 크기에 맞추기
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Text Field
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: CoconutColors.white),
            borderRadius: BorderRadius.circular(12),
            color: MyColors.transparentWhite_15,
          ),
          child: CupertinoTextField(
            focusNode: focusNode,
            controller: controller,
            keyboardType: keyboardType,
            placeholder: placeholder,
            padding: EdgeInsets.fromLTRB(prefix != null ? 0 : 16, 20, 16, 20),
            style: Styles.body2,
            cursorColor: cursorColor,
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            maxLength: maxLength,
            prefix: prefix,
            suffix: GestureDetector(
              onTap: () {
                onClear();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                child: SvgPicture.asset(
                  'assets/svg/text-field-clear.svg',
                  colorFilter: const ColorFilter.mode(
                    CoconutColors.white,
                    BlendMode.srcIn,
                  ),
                  width: 15,
                  height: 15,
                ),
              ),
            ),
            onChanged: (text) {
              String formattedText = formatInput?.call(text) ?? text;
              if (formattedText.runes.length > maxLength) {
                formattedText = String.fromCharCodes(formattedText.runes.take(maxLength));
                controller.text = formattedText;
              }
              onChanged(formattedText);
            },
          ),
        ),
        // 글자 수 표시
        Visibility(
          visible: visibleTextLimit,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Text(
                '${controller.text.runes.length}/$maxLength',
                style: TextStyle(
                  color: controller.text.runes.length == maxLength
                      ? CoconutColors.white
                      : MyColors.transparentWhite_50,
                  fontSize: 12,
                  fontFamily: CustomFonts.number.getFontFamily,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
