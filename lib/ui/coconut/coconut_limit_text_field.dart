import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CoconutLimitTextField extends StatelessWidget {
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

  const CoconutLimitTextField({
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
    final colors = context.coconutColors;
    final typography = context.coconutTypography;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colors.primaryText),
            borderRadius: BorderRadius.circular(12),
            color: colors.surface,
          ),
          child: CupertinoTextField(
            focusNode: focusNode,
            controller: controller,
            keyboardType: keyboardType,
            placeholder: placeholder,
            padding: EdgeInsets.fromLTRB(prefix != null ? 0 : 16, 20, 16, 20),
            style: typography.body.copyWith(color: colors.primaryText),
            cursorColor: cursorColor,
            decoration: const BoxDecoration(color: Colors.transparent),
            maxLength: maxLength,
            prefix: prefix,
            suffix:
                controller.text.isNotEmpty
                    ? GestureDetector(
                      onTap: onClear,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                        child: SvgPicture.asset(
                          'assets/svg/text-field-clear.svg',
                          colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
                          width: 15,
                          height: 15,
                        ),
                      ),
                    )
                    : null,
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
        Visibility(
          visible: visibleTextLimit,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Text(
                '${controller.text.runes.length}/$maxLength',
                style: typography.caption.copyWith(
                  color: controller.text.runes.length == maxLength ? colors.primaryText : colors.tertiaryText,
                  fontFamily: 'SpaceGrotesk',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
