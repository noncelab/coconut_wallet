import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class PassphraseTextField extends StatefulWidget {
  final TextEditingController passphraseController;
  final FocusNode passphraseFocusNode;
  final ValueChanged<String>? onChanged;

  const PassphraseTextField({
    super.key,
    required this.passphraseController,
    required this.passphraseFocusNode,
    this.onChanged,
  });

  @override
  State<PassphraseTextField> createState() => _PassphraseTextFieldState();
}

class _PassphraseTextFieldState extends State<PassphraseTextField> {
  bool _obscured = true;

  void _toggleVisibility() {
    setState(() => _obscured = !_obscured);
  }

  void _clear() {
    widget.passphraseController.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final strings = t.passphrase_input_text_field;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              _obscured ? strings.passphrase_visible : strings.passphrase_hidden,
              style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
            ),
            const Spacer(),
            IconButton(
              onPressed: _toggleVisibility,
              icon: Icon(
                _obscured ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                color: context.coconutColors.primaryText,
                size: 20,
              ),
            ),
          ],
        ),
        CoconutTextField(
          controller: widget.passphraseController,
          focusNode: widget.passphraseFocusNode,
          obscureText: _obscured,
          onChanged: (value) => widget.onChanged?.call(value),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          placeholderText: strings.placeholder,
          fontSize: 16,
          fontFamily: 'SpaceGrotesk',
          maxLines: 1,
          suffix: _buildClearSuffix(),
          maxLength: 100, // Trezor 50 characters
        ),
      ],
    );
  }

  Widget _buildClearSuffix() {
    return AnimatedBuilder(
      animation: widget.passphraseController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.passphraseController.text.isNotEmpty)
              GestureDetector(
                onTap: _clear,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: SvgPicture.asset(
                    CommonFormIconPath.textFieldClear,
                    width: 15,
                    height: 15,
                    colorFilter: ColorFilter.mode(context.coconutColors.tertiaryText, BlendMode.srcIn),
                  ),
                ),
              ),
            CoconutLayout.spacing_200w,
          ],
        );
      },
    );
  }
}
