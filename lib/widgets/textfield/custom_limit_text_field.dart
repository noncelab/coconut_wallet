import 'package:coconut_wallet/styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomLimitTextField extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final VoidCallback onClear;
  final int maxLength;

  const CustomLimitTextField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.maxLength = 30,
  });

  @override
  Widget build(BuildContext context) {
    final FocusNode focusNode = FocusNode();

    return Column(
      mainAxisSize: MainAxisSize.min, // 컨텐츠 크기에 맞추기
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Text Field
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: MyColors.white),
            borderRadius: BorderRadius.circular(12),
            color: MyColors.transparentWhite_15,
          ),
          child: CupertinoTextField(
            focusNode: focusNode,
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            style: Styles.body2,
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            maxLength: maxLength,
            suffix: GestureDetector(
              onTap: () {
                focusNode.unfocus();
                onClear();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 13),
                child: SvgPicture.asset(
                  'assets/svg/text-field-clear.svg',
                  colorFilter: const ColorFilter.mode(
                    MyColors.white,
                    BlendMode.srcIn,
                  ),
                  width: 15,
                  height: 15,
                ),
              ),
            ),
            onChanged: (text) {
              onChanged(text);
            },
          ),
        ),

        // 글자 수 표시
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Text(
              '${controller.text.length}/$maxLength',
              style: TextStyle(
                color: controller.text.length == maxLength
                    ? MyColors.white
                    : MyColors.transparentWhite_50,
                fontSize: 12,
                fontFamily: CustomFonts.text.getFontFamily,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
