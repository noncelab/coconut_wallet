import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/app/bootstrap/platform_channels.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';

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

  static const MethodChannel _channel = MethodChannel(methodChannelOS);

  @override
  State<CopyTextContainer> createState() => _CopyTextContainerState();
}

class _CopyTextContainerState extends State<CopyTextContainer> {
  late Color _textColor;
  late Color _buttonColor;
  late Color _iconColor;
  late int _prefixLength;
  bool _didInitThemeColors = false;

  @override
  void initState() {
    super.initState();
    _textColor = Colors.transparent;
    _buttonColor = Colors.transparent;
    _iconColor = Colors.transparent;
    _prefixLength = NetworkType.currentNetworkType == NetworkType.regtest ? 6 : 4;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitThemeColors) return;
    _textColor = context.coconutColors.primaryText;
    _buttonColor = context.coconutColors.surfaceMuted;
    _iconColor = context.coconutColors.iconDefault;
    _didInitThemeColors = true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return GestureDetector(
      onTap: () async {
        setState(() {
          _textColor = colors.primaryText;
          _buttonColor = colors.surfaceMuted;
          _iconColor = colors.iconDefault;
        });

        Clipboard.setData(ClipboardData(text: widget.copyText ?? widget.text)).then((value) => null);
        if (Platform.isAndroid) {
          try {
            final int version = await CopyTextContainer._channel.invokeMethod('getSdkVersion');

            // 안드로이드13 부터는 클립보드 복사 메세지가 나오기 때문에 예외 적용
            if (version > 31) {
              return;
            }
          } on PlatformException catch (e) {
            Logger.log("Failed to get platform version: '${e.message}'.");
          }
        }

        FToast fToast = FToast();

        if (!context.mounted) return;

        fToast.init(context);
        final toast = MyToast.getToastWidget(widget.toastMsg ?? t.copied);
        fToast.showToast(child: toast, gravity: ToastGravity.BOTTOM, toastDuration: const Duration(seconds: 2));
      },
      onTapDown: (details) {
        setState(() {
          _textColor = colors.secondaryText;
          _buttonColor = colors.surfacePressed;
          _iconColor = colors.iconSubDefault;
        });
      },
      onTapCancel: () {
        setState(() {
          _textColor = colors.primaryText;
          _buttonColor = colors.surfaceMuted;
          _iconColor = colors.iconDefault;
        });
      },
      child: Container(
        width: MediaQuery.sizeOf(context).width,
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CoconutStyles.radius_400),
          color: colors.surfaceCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildTextContent()),

                if (widget.middleText != null) ...[
                  CoconutLayout.spacing_400w,
                  Text(widget.middleText!, style: CoconutTypography.body2_14_Number.setColor(colors.tertiaryText)),
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
                style: widget.suffixTextStyle ?? CoconutTypography.body2_14.setColor(colors.tertiaryText),
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
    final colors = context.coconutColors;
    final text = widget.text;
    final address = extractAddressFromBip21(text);
    final schemeIndex = text.toLowerCase().startsWith('bitcoin:') ? 8 : 0;
    final queryStartIndex = schemeIndex + address.length;

    final spans = <TextSpan>[];
    if (schemeIndex > 0) {
      spans.add(
        TextSpan(text: text.substring(0, schemeIndex), style: CoconutTypography.body2_14.setColor(colors.tertiaryText)),
      );
    }

    if (address.length <= _prefixLength + 8) {
      spans.add(TextSpan(text: address, style: CoconutTypography.body2_14_Bold.setColor(colors.success)));
    } else {
      spans.add(
        TextSpan(
          text: address.substring(0, _prefixLength),
          style: CoconutTypography.body2_14_Bold.setColor(colors.tertiaryText),
        ),
      );
      spans.add(
        TextSpan(
          text: address.substring(_prefixLength, _prefixLength + 4),
          style: CoconutTypography.body2_14_Bold.setColor(colors.success),
        ),
      );
      spans.add(
        TextSpan(
          text: address.substring(_prefixLength + 4, address.length - 4),
          style: CoconutTypography.body2_14.setColor(colors.tertiaryText),
        ),
      );
      spans.add(
        TextSpan(
          text: address.substring(address.length - 4),
          style: CoconutTypography.body2_14_Bold.setColor(colors.success),
        ),
      );
    }

    if (queryStartIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(queryStartIndex),
          style: CoconutTypography.body2_14.setColor(colors.tertiaryText),
        ),
      );
    }

    return spans;
  }
}
