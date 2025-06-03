import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class WalletAddMfpInputBottomSheet extends StatefulWidget {
  final Function(String) onComplete;
  final VoidCallback onSkip;

  const WalletAddMfpInputBottomSheet({super.key, required this.onComplete, required this.onSkip});

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      _mfpFocusNode.requestFocus();
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
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sizes.size8, vertical: Sizes.size8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: CoconutColors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  Text(
                    t.wallet_add_input_screen.mfp_title,
                    style: CoconutTypography.body1_16,
                  ),
                  Visibility(
                    visible: false,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    maintainSemantics: false,
                    maintainInteractivity: false,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: CoconutColors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Sizes.size16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      padding: const EdgeInsets.all(CoconutStyles.radius_200),
                      decoration: const BoxDecoration(
                        color: CoconutColors.gray800,
                        borderRadius: BorderRadius.all(Radius.circular(CoconutStyles.radius_200)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SvgPicture.asset(
                                'assets/svg/circle-warning.svg',
                                colorFilter:
                                    const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                              ),
                              CoconutLayout.spacing_100w,
                              Text(t.wallet_add_input_screen.mfp_description_title,
                                  style: CoconutTypography.body2_14_Bold)
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
                                      text: t.wallet_add_input_screen.mfp_description_texts[0],
                                      style: CoconutTypography.body3_12,
                                      children: [
                                        TextSpan(
                                            text:
                                                "\n${t.wallet_add_input_screen.mfp_description_texts[1]}",
                                            style: CoconutTypography.body3_12),
                                        TextSpan(
                                            text:
                                                " ${t.wallet_add_input_screen.mfp_description_texts[2]}",
                                            style: CoconutTypography.body3_12_Bold)
                                      ],
                                    ),
                                  ),
                                ],
                              )),
                        ],
                      )),
                  CoconutLayout.spacing_600h,
                  CoconutTextField(
                      height: Sizes.size52,
                      padding:
                          const EdgeInsets.only(bottom: 0, left: Sizes.size14, right: Sizes.size14),
                      textAlign: TextAlign.left,
                      backgroundColor: CoconutColors.gray800,
                      errorColor: CoconutColors.hotPink,
                      cursorColor: CoconutColors.white,
                      activeColor: CoconutColors.white,
                      placeholderColor: CoconutColors.gray700,
                      controller: _mfpController,
                      focusNode: _mfpFocusNode,
                      maxLines: 1,
                      maxLength: 8,
                      fontFamily: 'SpaceGrotesk',
                      textInputAction: TextInputAction.done,
                      onChanged: (text) {},
                      isError: _isError,
                      isLengthVisible: true,
                      errorText: t.wallet_add_input_screen.format_error_text,
                      placeholderText: t.wallet_add_input_screen.mfp_input_placeholder,
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
                                  ? CoconutColors.hotPink
                                  : _mfpController.text.isNotEmpty
                                      ? CoconutColors.white
                                      : CoconutColors.gray700,
                              BlendMode.srcIn),
                        ),
                      )),
                  CoconutLayout.spacing_500h,
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: CoconutButton(
                          onPressed: () {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              FocusScope.of(context).unfocus();
                            });
                            widget.onSkip();
                            Navigator.pop(context);
                          },
                          textStyle: CoconutTypography.body2_14,
                          disabledBackgroundColor: CoconutColors.gray800,
                          disabledForegroundColor: CoconutColors.gray700,
                          isActive: true,
                          backgroundColor: CoconutColors.gray350,
                          foregroundColor: CoconutColors.black,
                          pressedTextColor: CoconutColors.black,
                          text: t.wallet_add_input_screen.mfp_skip,
                        ),
                      ),
                      CoconutLayout.spacing_200w,
                      Expanded(
                        flex: 6,
                        child: CoconutButton(
                          onPressed: () {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              FocusScope.of(context).unfocus();
                            });
                            widget.onComplete(_mfpController.text);
                            Navigator.pop(context);
                          },
                          disabledBackgroundColor: CoconutColors.gray800,
                          disabledForegroundColor: CoconutColors.gray700,
                          isActive: _isButtonEnabled,
                          backgroundColor: CoconutColors.white,
                          foregroundColor: CoconutColors.black,
                          pressedTextColor: CoconutColors.black,
                          text: t.complete,
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
    );
  }
}
