import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_add_input_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add_mfp_input_bottom_sheet.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

class WalletAddInputScreen extends StatefulWidget {
  const WalletAddInputScreen({super.key});

  @override
  State<WalletAddInputScreen> createState() => _WalletAddInputScreenState();
}

class _WalletAddInputScreenState extends State<WalletAddInputScreen> {
  final TextEditingController _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  bool _isError = false;
  bool _isWalletInfoExpanded = false;
  bool _isButtonEnabled = false;
  bool _hasAddedListener = false;
  bool _isProcessing = false;

  bool get isDescriptorAdding => _inputController.text.contains('['); // 대괄호 입력시 descriptor 입력을 가정

  Future<void> _addWallet(WalletAddInputViewModel viewModel) async {
    _closeKeyboard();
    if (_isProcessing) return;

    _isProcessing = true;
    context.loaderOverlay.show();
    await Future.delayed(const Duration(seconds: 2));
    try {
      if (!mounted) return;
      ResultOfSyncFromVault addResult = await viewModel.addWallet();

      if (!mounted) return;
      switch (addResult.result) {
        case WalletSyncResult.newWalletAdded:
          {
            context.read<AnalyticsService>().logEvent(
              eventName: AnalyticsEventNames.walletAddCompleted,
              parameters: {AnalyticsParameterNames.walletAddImportSource: WalletImportSource.extendedPublicKey.name},
            );

            if (mounted) {
              Navigator.pop(context, addResult);
            }
            break;
          }
        case WalletSyncResult.existingWalletUpdateImpossible:
          vibrateLightDouble();
          if (mounted) {
            CustomDialogs.showCustomAlertDialog(
              context,
              title: t.alert.wallet_add.already_exist,
              message: t.alert.wallet_add.already_exist_description(
                name: TextUtils.ellipsisIfLonger(viewModel.getWalletName(addResult.walletId!), maxLength: 15),
              ),
              onConfirm: () {
                _isProcessing = false;
                Navigator.pop(context);
              },
            );
          }
        default:
          throw 'No Support Result: ${addResult.result.name}';
      }
    } catch (e) {
      vibrateLightDouble();
      if (mounted) {
        CustomDialogs.showCustomAlertDialog(
          context,
          title: t.alert.wallet_add.add_failed,
          message: e.toString(),
          onConfirm: () {
            _isProcessing = false;
            Navigator.pop(context);
          },
        );
      }
    } finally {
      vibrateMedium();
      if (mounted) {
        context.loaderOverlay.hide();
      }
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _closeKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _handleInput(BuildContext context) {
    final viewModel = context.read<WalletAddInputViewModel>();
    if (_inputController.text.isEmpty) {
      setState(() {
        _isButtonEnabled = false;
        _isError = false;
      });
      return;
    }

    setState(() {
      _isButtonEnabled =
          viewModel.isValidCharacters(_inputController.text) &&
          (isDescriptorAdding
              ? viewModel.normalizeDescriptor(_inputController.text)
              : viewModel.isExtendedPublicKey(_inputController.text));
      _isError = !_isButtonEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WalletAddInputViewModel(context.read<WalletProvider>(), context.read<PreferenceProvider>()),
      child: Consumer<WalletAddInputViewModel>(
        builder: (context, viewModel, child) {
          if (!_hasAddedListener) {
            _inputController.addListener(() {
              _handleInput(context);
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
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              CoconutLayout.spacing_600h,
                              CoconutTextField(
                                textInputFormatter: [FilteringTextInputFormatter.deny(RegExp(r'\s+'))],
                                textAlign: TextAlign.left,
                                backgroundColor: CoconutColors.gray800,
                                errorColor: CoconutColors.hotPink,
                                cursorColor: CoconutColors.white,
                                activeColor: CoconutColors.white,
                                placeholderColor: CoconutColors.gray700,
                                controller: _inputController,
                                focusNode: _inputFocusNode,
                                maxLines: 5,
                                fontFamily: 'SpaceGrotesk',
                                textInputAction: TextInputAction.done,
                                onChanged: (text) {},
                                isError: _isError,
                                isLengthVisible: false,
                                errorText: viewModel.errorMessage,
                                placeholderText: t.wallet_add_input_screen.placeholder_text,
                                suffix: IconButton(
                                  iconSize: 14,
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    setState(() {
                                      _inputController.text = '';
                                    });
                                  },
                                  icon: SvgPicture.asset(
                                    'assets/svg/text-field-clear.svg',
                                    colorFilter: ColorFilter.mode(
                                      _isError
                                          ? CoconutColors.hotPink
                                          : _inputController.text.isNotEmpty
                                          ? CoconutColors.white
                                          : CoconutColors.gray700,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                              CoconutLayout.spacing_900h,
                              Container(
                                padding: const EdgeInsets.all(CoconutStyles.radius_200),
                                decoration: const BoxDecoration(
                                  color: CoconutColors.gray800,
                                  borderRadius: BorderRadius.all(Radius.circular(CoconutStyles.radius_200)),
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
                                              _isWalletInfoExpanded
                                                  ? 'assets/svg/circle-warning.svg'
                                                  : 'assets/svg/circle-help.svg',
                                              width: 18,
                                              colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                                            ),
                                            CoconutLayout.spacing_100w,
                                            Expanded(
                                              child: Text(
                                                t.wallet_add_input_screen.wallet_description_text,
                                                style: CoconutTypography.body2_14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (_isWalletInfoExpanded) ...[
                                      CoconutLayout.spacing_200h,
                                      _buildWalletInfo(
                                        titleText: t.wallet_add_input_screen.blue_wallet_texts[0],
                                        descriptionList: [
                                          ...t.wallet_add_input_screen.blue_wallet_texts.getRange(1, 3),
                                        ],
                                        addressText: t.wallet_add_input_screen.blue_wallet_texts[3],
                                      ),
                                      CoconutLayout.spacing_200h,
                                      _buildWalletInfo(
                                        titleText: t.wallet_add_input_screen.nunchuck_wallet_texts[0],
                                        descriptionList: [
                                          ...t.wallet_add_input_screen.nunchuck_wallet_texts.getRange(1, 2),
                                        ],
                                        addressText:
                                            Platform.isAndroid
                                                ? t.wallet_add_input_screen.nunchuck_wallet_texts[2]
                                                : t.wallet_add_input_screen.nunchuck_wallet_texts[3],
                                      ),
                                      CoconutLayout.spacing_200h,
                                    ],
                                  ],
                                ),
                              ),
                              CoconutLayout.spacing_2500h,
                            ],
                          ),
                        ),
                        FixedBottomButton(
                          onButtonClicked: () {
                            if (isDescriptorAdding) {
                              _addWallet(viewModel);
                            } else {
                              // 확장공개키의 경우에는 Master Finger Print를 추가로 입력받는다.
                              showMfpInputBottomSheet(viewModel);
                            }
                          },
                          text: t.complete,
                          showGradient: true,
                          gradientPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 40, top: 110),
                          horizontalPadding: 0,
                          isActive: _isButtonEnabled,
                          backgroundColor: CoconutColors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void showMfpInputBottomSheet(WalletAddInputViewModel viewModel) async {
    _closeKeyboard();

    await Future.delayed(const Duration(milliseconds: 300));

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: WalletAddMfpInputBottomSheet(
            onSkip: () {
              viewModel.masterFingerPrint = null;
              _addWallet(viewModel);
            },
            onComplete: (text) {
              viewModel.masterFingerPrint = text;
              _addWallet(viewModel);
            },
          ),
        );
      },
      backgroundColor: CoconutColors.black,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
    );
  }

  Widget _buildWalletInfo({
    required String titleText,
    required List<String> descriptionList,
    required String addressText,
  }) {
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
                  padding: const EdgeInsets.symmetric(horizontal: Sizes.size12, vertical: Sizes.size8),
                  child: RichText(
                    text: TextSpan(
                      text: addressText.substring(0, 4),
                      style:
                          addressText.startsWith("zpub")
                              ? CoconutTypography.body3_12_NumberBold
                              : CoconutTypography.body3_12_Number,
                      children: [TextSpan(text: addressText.substring(4), style: CoconutTypography.body3_12_Number)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
