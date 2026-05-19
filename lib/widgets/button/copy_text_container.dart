import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/clipboard_copy_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class CopyTextContainer extends StatefulWidget {
  final String text;
  final String? copyText;
  final String? middleText;
  final String? suffixText;
  final TextStyle? suffixTextStyle;
  final String? toastMsg;
  final TextAlign? textAlign;
  final TextStyle? textStyle;
  final RichText? textRichText;
  final bool showButton;
  final bool isAddress;
  final EdgeInsets? padding;

  const CopyTextContainer({
    super.key,
    required this.text,
    this.copyText,
    this.middleText,
    this.suffixText,
    this.suffixTextStyle,
    this.toastMsg,
    this.textAlign,
    this.textStyle,
    this.textRichText,
    this.showButton = true,
    this.isAddress = false,
    this.padding,
  });
  @override
  State<CopyTextContainer> createState() => _CopyTextContainerState();
}

class _CopyTextContainerState extends State<CopyTextContainer> {
  late Color _textColor;
  late Color _buttonColor;
  late Color _iconColor;
  late int _prefixLength;

  @override
  void initState() {
    super.initState();
    _textColor = CoconutColors.white;
    _buttonColor = CoconutColors.gray800;
    _iconColor = CoconutColors.white;
    _prefixLength = NetworkType.currentNetworkType == NetworkType.regtest ? 6 : 4;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        setState(() {
          _textColor = CoconutColors.white;
          _buttonColor = CoconutColors.gray800;
          _iconColor = CoconutColors.white;
        });

        await ClipboardCopyUtil.copyWithToast(
          context,
          text: widget.copyText ?? widget.text,
          toastMessage: widget.toastMsg,
        );
      },
      onTapDown: (details) {
        setState(() {
          _textColor = CoconutColors.gray400;
          _buttonColor = CoconutColors.gray900;
          _iconColor = CoconutColors.gray400;
        });
      },
      onTapCancel: () {
        setState(() {
          _textColor = CoconutColors.white;
          _buttonColor = CoconutColors.gray800;
          _iconColor = CoconutColors.white;
        });
      },
      child: Container(
        width: MediaQuery.sizeOf(context).width,
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CoconutStyles.radius_400),
          color: CoconutColors.gray850,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildTextContent()),

                if (widget.middleText != null) ...[
                  CoconutLayout.spacing_400w,
                  Text(widget.middleText!, style: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray500)),
                  CoconutLayout.spacing_200w,
                ] else ...[
                  CoconutLayout.spacing_400w,
                ],

                if (widget.showButton)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(CoconutStyles.radius_100),
                      color: _buttonColor,
                    ),
                    child: SvgPicture.asset(
                      'assets/svg/copy.svg',
                      colorFilter: ColorFilter.mode(_iconColor, BlendMode.srcIn),
                    ),
                  ),
              ],
            ),
            if (widget.suffixText != null) ...[
              CoconutLayout.spacing_100h,
              Text(
                widget.suffixText!,
                style: widget.suffixTextStyle ?? CoconutTypography.body2_14.setColor(CoconutColors.gray500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    if (widget.textRichText != null) {
      return RichText(text: widget.textRichText!.text);
    }

    if (widget.isAddress) {
      return Text.rich(TextSpan(children: _buildAddressSpans()));
    }

    return Text(
      widget.text,
      textAlign: widget.textAlign ?? TextAlign.start,
      style: widget.textStyle?.setColor(_textColor) ?? CoconutTypography.body1_16_Number.setColor(_textColor),
    );
  }

  List<TextSpan> _buildAddressSpans() {
    final text = widget.text;
    final address = extractAddressFromBip21(text);
    final schemeIndex = text.toLowerCase().startsWith('bitcoin:') ? 8 : 0;
    final queryStartIndex = schemeIndex + address.length;

    final spans = <TextSpan>[];
    if (schemeIndex > 0) {
      spans.add(
        TextSpan(
          text: text.substring(0, schemeIndex),
          style: CoconutTypography.body2_14.setColor(CoconutColors.gray500),
        ),
      );
    }

    if (address.length <= _prefixLength + 8) {
      spans.add(TextSpan(text: address, style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.cyanBlue)));
    } else {
      spans.add(
        TextSpan(
          text: address.substring(0, _prefixLength),
          style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.gray500),
        ),
      );
      spans.add(
        TextSpan(
          text: address.substring(_prefixLength, _prefixLength + 4),
          style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.cyanBlue),
        ),
      );
      spans.add(
        TextSpan(
          text: address.substring(_prefixLength + 4, address.length - 4),
          style: CoconutTypography.body2_14.setColor(CoconutColors.gray500),
        ),
      );
      spans.add(
        TextSpan(
          text: address.substring(address.length - 4),
          style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.cyanBlue),
        ),
      );
    }

    if (queryStartIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(queryStartIndex),
          style: CoconutTypography.body2_14.setColor(CoconutColors.gray500),
        ),
      );
    }

    return spans;
  }
}
