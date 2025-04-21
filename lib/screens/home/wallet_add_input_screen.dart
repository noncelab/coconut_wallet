import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_add_input_view_model.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

import '../../providers/wallet_provider.dart';

class WalletAddInputScreen extends StatefulWidget {
  const WalletAddInputScreen({super.key});

  @override
  State<WalletAddInputScreen> createState() => _WalletAddInputScreenState();
}

class _WalletAddInputScreenState extends State<WalletAddInputScreen> {
  final TextEditingController _xpubInputController = TextEditingController();
  final _xpubInputFocusNode = FocusNode();
  bool _isXpubError = false;
  bool _isWalletInfoExpanded = false;
  bool _isButtonEnabled = false;
  bool _hasAddedListener = false;

  void _onButtonPressed() {}

  @override
  void dispose() {
    _xpubInputController.dispose();
    _xpubInputFocusNode.dispose();
    super.dispose();
  }

  void _closeKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _handleXpubInput(BuildContext context) {
    final viewModel = context.read<WalletAddInputViewModel>();
    if (_xpubInputController.text.isEmpty) {
      setState(() {
        _isButtonEnabled = false;
        _isXpubError = false;
      });
      return;
    }

    setState(() {
      _isButtonEnabled = viewModel.isExtendedPublicKey(
            _xpubInputController.text,
          ) ||
          viewModel.isDescriptor(_xpubInputController.text);
      _isXpubError = !_isButtonEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (_) => WalletAddInputViewModel(
              context.read<WalletProvider>(),
            ),
        child: Consumer<WalletAddInputViewModel>(builder: (context, viewModel, child) {
          if (!_hasAddedListener) {
            _xpubInputController.addListener(() {
              _handleXpubInput(context);
            });
            _hasAddedListener = true;
          }
          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, _) {},
            child: GestureDetector(
              onTap: _closeKeyboard,
              child: Scaffold(
                  backgroundColor: CoconutColors.black,
                  appBar: CoconutAppBar.build(
                    title: t.wallet_add_input_screen.app_bar_title_text,
                    context: context,
                    isBottom: true,
                  ),
                  body: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              CoconutLayout.spacing_600h,
                              CoconutTextField(
                                  textAlign: TextAlign.left,
                                  backgroundColor: CoconutColors.gray800,
                                  errorColor: CoconutColors.hotPink,
                                  cursorColor: CoconutColors.white,
                                  activeColor: CoconutColors.white,
                                  placeholderColor: CoconutColors.gray700,
                                  controller: _xpubInputController,
                                  focusNode: _xpubInputFocusNode,
                                  maxLines: 5,
                                  textInputAction: TextInputAction.done,
                                  onChanged: (text) {},
                                  isError: _isXpubError,
                                  isLengthVisible: false,
                                  errorText: t.wallet_add_input_screen.error_text,
                                  placeholderText: t.wallet_add_input_screen.placeholder_text,
                                  suffix: IconButton(
                                    iconSize: 14,
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      setState(() {
                                        _xpubInputController.text = '';
                                      });
                                    },
                                    icon: SvgPicture.asset(
                                      'assets/svg/text-field-clear.svg',
                                      colorFilter: ColorFilter.mode(
                                          _isXpubError
                                              ? CoconutColors.hotPink
                                              : _xpubInputController.text.isNotEmpty
                                                  ? CoconutColors.white
                                                  : CoconutColors.gray700,
                                          BlendMode.srcIn),
                                    ),
                                  )),
                              CoconutLayout.spacing_900h,
                              Container(
                                  padding: const EdgeInsets.all(CoconutStyles.radius_200),
                                  decoration: const BoxDecoration(
                                    color: CoconutColors.gray800,
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(CoconutStyles.radius_200)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isWalletInfoExpanded = !_isWalletInfoExpanded;
                                          });
                                        },
                                        child: Container(
                                          color: Colors.transparent, // touch event
                                          child: Row(
                                            children: [
                                              SvgPicture.asset(
                                                'assets/svg/circle-help.svg',
                                                colorFilter: const ColorFilter.mode(
                                                    CoconutColors.white, BlendMode.srcIn),
                                              ),
                                              CoconutLayout.spacing_100w,
                                              Text(
                                                  t.wallet_add_input_screen.wallet_description_text,
                                                  style: CoconutTypography.body3_12)
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (_isWalletInfoExpanded) ...[
                                        CoconutLayout.spacing_200h,
                                        _buildWalletInfo(
                                            titleText:
                                                t.wallet_add_input_screen.blue_wallet_texts[0],
                                            descriptionList: [
                                              ...t.wallet_add_input_screen.blue_wallet_texts
                                                  .getRange(1, 3)
                                            ],
                                            addressText:
                                                t.wallet_add_input_screen.blue_wallet_texts[3]),
                                        CoconutLayout.spacing_200h,
                                        _buildWalletInfo(
                                            titleText:
                                                t.wallet_add_input_screen.nunchuck_wallet_texts[0],
                                            descriptionList: [
                                              ...t.wallet_add_input_screen.nunchuck_wallet_texts
                                                  .getRange(1, 2)
                                            ],
                                            addressText: Platform.isAndroid
                                                ? t.wallet_add_input_screen.nunchuck_wallet_texts[2]
                                                : t.wallet_add_input_screen
                                                    .nunchuck_wallet_texts[3]),
                                        CoconutLayout.spacing_200h,
                                      ]
                                    ],
                                  )),
                            ],
                          ),
                        ),
                        FixedBottomButton(
                          onButtonClicked: _onButtonPressed,
                          text: t.complete,
                          showGradient: true,
                          gradientPadding:
                              const EdgeInsets.only(left: 16, right: 16, bottom: 40, top: 110),
                          horizontalPadding: 0,
                          isActive: _isButtonEnabled,
                          backgroundColor: CoconutColors.white,
                        ),
                      ],
                    ),
                  )),
            ),
          );
        }));
  }

  Widget _buildWalletInfo(
      {required String titleText,
      required List<String> descriptionList,
      required String addressText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titleText, style: CoconutTypography.body3_12),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.size12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...descriptionList.map((desc) => Text(desc, style: CoconutTypography.body3_12)),
                CoconutLayout.spacing_200h,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Sizes.size8),
                  child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: CoconutColors.black,
                        borderRadius: BorderRadius.all(Radius.circular(CoconutStyles.radius_100)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: Sizes.size12, vertical: Sizes.size8),
                      child: Text(addressText, style: CoconutTypography.caption_10_NumberBold)),
                )
              ],
            ))
      ],
    );
  }
}
