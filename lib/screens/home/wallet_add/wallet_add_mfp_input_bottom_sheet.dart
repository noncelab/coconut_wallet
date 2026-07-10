import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class WalletAddMfpInputBottomSheet extends StatefulWidget {
  final Function(String) onComplete;
  final VoidCallback? onSkip;

  const WalletAddMfpInputBottomSheet({super.key, required this.onComplete, this.onSkip});

  @override
  State<WalletAddMfpInputBottomSheet> createState() => _WalletAddMfpInputBottomSheetState();
}

class _WalletAddMfpInputBottomSheetState extends State<WalletAddMfpInputBottomSheet> {
  final TextEditingController _mfpController = TextEditingController();
  final FocusNode _mfpFocusNode = FocusNode();
  final mfpRegex = RegExp("[0-9a-fA-F]{8}");
  bool _isError = false;
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _mfpFocusNode.requestFocus();
      }
    });

    _mfpController.addListener(() {
      if (_mfpController.text.length < 8) {
        setState(() {
          _isButtonEnabled = false;
          _isError = false;
        });
        return;
      }

      setState(() {
        _isButtonEnabled = mfpRegex.hasMatch(_mfpController.text);
        _isError = !_isButtonEnabled;
      });
    });
  }

  @override
  void dispose() {
    _mfpController.dispose();
    _mfpFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sizes.size8, vertical: Sizes.size8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, color: context.coconutColors.iconDefault),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    Text(
                      t.wallet_add_scanner_screen.paste.mfp_title,
                      style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
                    ),
                    Visibility(
                      visible: false,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      maintainSemantics: false,
                      maintainInteractivity: false,
                      child: IconButton(
                        icon: Icon(Icons.close, color: context.coconutColors.iconDefault),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sizes.size16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(CoconutStyles.radius_200),
                      decoration: BoxDecoration(
                        color: context.coconutColors.surfaceCard,
                        borderRadius: const BorderRadius.all(Radius.circular(CoconutStyles.radius_200)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SvgPicture.asset(
                                'assets/svg/circle-warning.svg',
                                colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
                              ),
                              CoconutLayout.spacing_100w,
                              Text(
                                t.wallet_add_scanner_screen.paste.mfp_description_title,
                                style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
                              ),
                            ],
                          ),
                          CoconutLayout.spacing_200h,
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Sizes.size8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    text: t.wallet_add_scanner_screen.paste.mfp_description_texts[0],
                                    style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
                                    children: [
                                      TextSpan(
                                        text: " ${t.wallet_add_scanner_screen.paste.mfp_description_texts[1]}",
                                        style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
                                      ),
                                      TextSpan(
                                        text: " ${t.wallet_add_scanner_screen.paste.mfp_description_texts[2]}",
                                        style: CoconutTypography.body3_12_Bold.setColor(
                                          context.coconutColors.primaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    CoconutLayout.spacing_600h,
                    CoconutTextField(
                      height: Sizes.size52,
                      padding: const EdgeInsets.only(bottom: 0, left: Sizes.size14, right: Sizes.size14),
                      textAlign: TextAlign.left,
                      backgroundColor: context.coconutColors.inputSurface,
                      errorColor: context.coconutColors.danger,
                      cursorColor: context.coconutColors.primaryText,
                      activeColor: context.coconutColors.primaryText,
                      placeholderColor: context.coconutColors.inputPlaceholder,
                      borderColor: context.coconutColors.inputBorder,
                      controller: _mfpController,
                      focusNode: _mfpFocusNode,
                      maxLines: 1,
                      maxLength: 8,
                      fontFamily: 'SpaceGrotesk',
                      textInputAction: TextInputAction.done,
                      onChanged: (text) {},
                      isError: _isError,
                      isLengthVisible: true,
                      errorText: t.wallet_add_scanner_screen.paste.format_error_text,
                      placeholderText: t.wallet_add_scanner_screen.paste.mfp_input_placeholder,
                      suffix: IconButton(
                        iconSize: 14,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _mfpController.text = '';
                          });
                        },
                        icon: SvgPicture.asset(
                          'assets/svg/text-field-clear.svg',
                          colorFilter: ColorFilter.mode(
                            _isError
                                ? context.coconutColors.danger
                                : _mfpController.text.isNotEmpty
                                ? context.coconutColors.primaryText
                                : context.coconutColors.inputPlaceholder,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    CoconutLayout.spacing_500h,
                    Row(
                      children: [
                        if (widget.onSkip != null) ...[
                          Expanded(
                            flex: 4,
                            child: CoconutButton(
                              onPressed: () {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  FocusScope.of(context).unfocus();
                                });
                                widget.onSkip?.call();
                              },
                              height: Platform.isAndroid ? 55 : 58,
                              textStyle: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                              disabledBackgroundColor: context.coconutColors.surfaceDisabled,
                              disabledForegroundColor: context.coconutColors.tertiaryText,
                              isActive: true,
                              backgroundColor: context.coconutColors.secondaryButtonBackground,
                              foregroundColor: context.coconutColors.secondaryButtonText,
                              pressedTextColor: context.coconutColors.secondaryButtonText,
                              text: t.wallet_add_scanner_screen.paste.mfp_skip,
                            ),
                          ),
                          CoconutLayout.spacing_200w,
                        ],
                        Expanded(
                          flex: 6,
                          child: CoconutButton(
                            onPressed: () {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                FocusScope.of(context).unfocus();
                              });
                              widget.onComplete(_mfpController.text);
                            },
                            height: Platform.isAndroid ? 55 : 58,
                            disabledBackgroundColor: context.coconutColors.surfaceDisabled,
                            disabledForegroundColor: context.coconutColors.tertiaryText,
                            isActive: _isButtonEnabled,
                            backgroundColor: context.coconutColors.primaryButtonBackground,
                            foregroundColor: context.coconutColors.primaryButtonText,
                            pressedTextColor: context.coconutColors.primaryButtonText,
                            text: t.done,
                          ),
                        ),
                      ],
                    ),
                    CoconutLayout.spacing_600h,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
