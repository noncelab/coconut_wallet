import 'dart:io';
import 'package:coconut_wallet/constants/icon_path.dart';

import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutTextField, CoconutTextFieldStyle;
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_tween_button.dart';
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
    final backgroundColor = context.coconutColors.surfaceBottomSheet;
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final statusBarHeight = mediaQuery.padding.top;
    final androidBottomSystemHeight =
        Theme.of(context).platform == TargetPlatform.android ? mediaQuery.viewPadding.bottom : 0.0;
    final computedMaxBodyHeight = mediaQuery.size.height - statusBarHeight - androidBottomSystemHeight;
    const estimatedHeaderHeight = 108.0;
    const bottomSpacing = 16.0;
    final maxAllowedBodyHeight = computedMaxBodyHeight - estimatedHeaderHeight - bottomSpacing - 44;
    final resolvedBodyHeight = maxAllowedBodyHeight.clamp(240.0, 360.0);
    final effectiveBodyHeight = (resolvedBodyHeight - (keyboardInset > 0 ? keyboardInset * 0.16 : 0.0)).clamp(
      240.0,
      resolvedBodyHeight,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        child: ColoredBox(
          color: backgroundColor,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: SafeArea(
              child: Container(
                color: backgroundColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: SizedBox(
                          width: 55,
                          height: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: context.coconutColors.secondaryText,
                              borderRadius: const BorderRadius.all(Radius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Icon(Icons.close_rounded, size: 24, color: context.coconutColors.primaryText),
                          ),
                          Expanded(
                            child: Text(
                              t.wallet_add_scanner_screen.paste.mfp_title,
                              style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 24),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      height: effectiveBodyHeight,
                      child: Stack(
                        children: [
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildBody(context)),
                          if (widget.onSkip != null)
                            FixedBottomTweenButton(
                              isVisibleAboveKeyboard: false,
                              showSurroundings: true,
                              surroundingsColor: backgroundColor,
                              bottomPadding: FixedBottomButton.fixedBottomButtonDefaultBottomPadding,
                              buttonHeight: Platform.isAndroid ? 50 : 53,
                              leftButtonRatio: 0.4,
                              leftButtonClicked: () {
                                FocusScope.of(context).unfocus();
                                widget.onSkip?.call();
                              },
                              rightButtonClicked: () {
                                FocusScope.of(context).unfocus();
                                widget.onComplete(_mfpController.text);
                              },
                              leftText: t.wallet_add_scanner_screen.paste.mfp_skip,
                              rightText: t.done,
                              isLeftButtonActive: true,
                              isRightButtonActive: _isButtonEnabled,
                            )
                          else
                            FixedBottomButton(
                              isVisibleAboveKeyboard: false,
                              isActive: _isButtonEnabled,
                              showSurroundings: true,
                              surroundingsColor: backgroundColor,
                              bottomPadding: FixedBottomButton.fixedBottomButtonDefaultBottomPadding,
                              buttonHeight: Platform.isAndroid ? 50 : 53,
                              onButtonClicked: () {
                                FocusScope.of(context).unfocus();
                                widget.onComplete(_mfpController.text);
                              },
                              text: t.done,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    const double bottomSpacer =
        FixedBottomButton.fixedBottomButtonDefaultHeight + FixedBottomButton.fixedBottomButtonDefaultBottomPadding + 44;

    return SizedBox(
      height: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: bottomSpacer),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(CoconutStyles.radius_200),
              decoration: BoxDecoration(
                color: context.coconutColors.surface,
                borderRadius: const BorderRadius.all(Radius.circular(CoconutStyles.radius_200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        CommonStateIconPath.circleWarning,
                        colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
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
                                style: CoconutTypography.body3_12_Bold.setColor(context.coconutColors.primaryText),
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
              clearButtonVisibility: CoconutTextFieldClearButtonVisibility.always,
              onClear: () {
                setState(() {
                  _mfpController.text = '';
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
