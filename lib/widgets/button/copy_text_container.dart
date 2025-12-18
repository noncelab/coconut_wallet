import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/main.dart';
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
  final String? toastMsg;
  final TextAlign? textAlign;
  final TextStyle? textStyle;
  final RichText? textRichText;
  final bool showButton;
  final bool isAddress;

  const CopyTextContainer({
    super.key,
    required this.text,
    this.copyText,
    this.middleText,
    this.toastMsg,
    this.textAlign,
    this.textStyle,
    this.textRichText,
    this.showButton = true,
    this.isAddress = false,
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CoconutStyles.radius_400),
          color: CoconutColors.black,
        ),
        child: Row(
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
      ),
    );
  }

  Widget _buildTextContent() {
    if (widget.textRichText != null) {
      return RichText(text: widget.textRichText!.text);
    }

    if (widget.isAddress) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: widget.text.substring(0, _prefixLength),
              style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.gray500),
            ),
            TextSpan(
              text: widget.text.substring(_prefixLength, _prefixLength + 4),
              style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.cyanBlue),
            ),
            TextSpan(
              text: widget.text.substring(_prefixLength + 4, widget.text.length - 4),
              style: CoconutTypography.body2_14.setColor(CoconutColors.gray500),
            ),
            TextSpan(
              text: widget.text.substring(widget.text.length - 4),
              style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.cyanBlue),
            ),
          ],
        ),
      );
    }

    return Text(
      widget.text,
      textAlign: widget.textAlign ?? TextAlign.start,
      style: widget.textStyle?.setColor(_textColor) ?? CoconutTypography.body1_16_Number.setColor(_textColor),
    );
  }
}
