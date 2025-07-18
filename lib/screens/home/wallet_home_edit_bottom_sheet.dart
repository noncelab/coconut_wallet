import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/preference/home_feature.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_home_edit_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/fake_balance_bottom_sheet.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/multi_button.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class WalletHomeEditBottomSheet extends StatefulWidget {
  const WalletHomeEditBottomSheet({
    super.key,
  });

  @override
  State<WalletHomeEditBottomSheet> createState() => _WalletHomeEditBottomSheetState();
}

class _WalletHomeEditBottomSheetState extends State<WalletHomeEditBottomSheet>
    with TickerProviderStateMixin {
  final TextEditingController _textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late WalletHomeEditViewModel _viewModel;

  GlobalKey fixedBottomButtonKey = GlobalKey();
  Size _fixedBottomButtonSize = const Size(0, 0);

  final FocusNode _textFieldFocusNode = FocusNode();
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 하단 버튼 사이즈 계산
      if (fixedBottomButtonKey.currentContext != null) {
        final fixedBottomButtonRenderBox =
            fixedBottomButtonKey.currentContext?.findRenderObject() as RenderBox;
        setState(() {
          _fixedBottomButtonSize = fixedBottomButtonRenderBox.size;
        });
      }

      if (_viewModel.tempFakeBalanceTotalBtc != null) {
        if (_viewModel.tempFakeBalanceTotalBtc == 0) {
          // 0일 때
          _textEditingController.text = '0';
        } else if (_viewModel.tempFakeBalanceTotalBtc! % 1 == 0) {
          // 정수일 때
          _textEditingController.text = _viewModel.tempFakeBalanceTotalBtc.toString().split('.')[0];
        } else {
          _textEditingController.text = _viewModel.tempFakeBalanceTotalBtc.toString();
        }
      }

      _textFieldFocusNode.addListener(() {
        if (_textFieldFocusNode.hasFocus) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _fixedBottomButtonSize.height,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        }
      });

      _textEditingController.addListener(() {
        double? input;
        if (_textEditingController.text.isEmpty) {
          _viewModel.setTempFakeBalanceTotalBtc(null);
        }
        try {
          input = double.parse(_textEditingController.text);
        } catch (e) {
          debugPrint(e.toString());
        }

        setState(() {
          _viewModel.setTempFakeBalanceTotalBtc(input);
          if (_viewModel.tempFakeBalanceTotalBtc == null) {
            _viewModel.setInputError(FakeBalanceInputError.none);
          } else {
            if (_viewModel.tempFakeBalanceTotalBtc! > 0 &&
                _viewModel.tempFakeBalanceTotalBtc! <
                    UnitUtil.convertSatoshiToBitcoin(_viewModel.minimumSatoshi)) {
              _viewModel.setInputError(FakeBalanceInputError.notEnoughForAllWallets);
            } else if (_viewModel.tempFakeBalanceTotalBtc! > _viewModel.maximumAmount) {
              _viewModel.setInputError(FakeBalanceInputError.exceedsTotalSupply);
            } else {
              _viewModel.setInputError(FakeBalanceInputError.none);
            }
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  WalletHomeEditViewModel _createViewModel() {
    _viewModel = WalletHomeEditViewModel(
      context.read<WalletProvider>(),
      context.read<PreferenceProvider>(),
    );
    return _viewModel;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<WalletProvider, PreferenceProvider,
        WalletHomeEditViewModel>(
      create: (context) => _createViewModel(),
      update: (context, walletProvider, preferenceProvider, previous) {
        previous ??= _createViewModel();
        previous.onPreferenceProviderUpdated();
        return previous..onWalletProviderUpdated(walletProvider);
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          appBar: CoconutAppBar.build(
            context: context,
            isBottom: true,
            onBackPressed: () {
              if (_shouldEnableCompleteButton()) {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return CoconutPopup(
                      title: t.wallet_list.edit.finish,
                      description: t.wallet_list.edit.unsaved_changes_confirm_exit,
                      leftButtonText: t.cancel,
                      rightButtonText: t.confirm,
                      onTapRight: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      onTapLeft: () {
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
          body: Stack(
            children: [
              Container(
                height: MediaQuery.sizeOf(context).height,
                color: CoconutColors.black,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CoconutLayout.spacing_100h,
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 30,
                        ),
                        child: Text(
                          t.wallet_home_screen.edit.title,
                          style: CoconutTypography.heading3_21_Bold,
                        ),
                      ),
                      const Divider(
                        height: 1,
                        color: CoconutColors.gray700,
                      ),
                      if (context.read<WalletProvider>().walletItemList.isNotEmpty) ...[
                        CoconutLayout.spacing_200h,
                        Consumer<WalletHomeEditViewModel>(
                          builder: (context, viewModel, child) {
                            return Column(
                              children: [
                                MultiButton(
                                  backgroundColor: Colors.transparent,
                                  showDivider: false,
                                  children: [
                                    SingleButton(
                                      title: t.wallet_home_screen.edit.hide_balance,
                                      subtitle: t.wallet_home_screen.edit.hide_balance_on_home,
                                      subtitleStyle: CoconutTypography.body3_12.setColor(
                                        CoconutColors.gray400,
                                      ),
                                      onPressed: () async {
                                        if (_textFieldFocusNode.hasFocus) {
                                          FocusScope.of(context).unfocus();
                                          return;
                                        }
                                        viewModel
                                            .setTempIsBalanceHidden(!viewModel.tempIsBalanceHidden);
                                      },
                                      backgroundColor: Colors.transparent,
                                      rightElement: CupertinoSwitch(
                                        value: viewModel.tempIsBalanceHidden,
                                        activeColor: CoconutColors.gray100,
                                        trackColor: CoconutColors.gray600,
                                        thumbColor: CoconutColors.gray800,
                                        onChanged: (value) {
                                          viewModel.setTempIsBalanceHidden(value);
                                        },
                                      ),
                                    ),
                                    if (viewModel.tempIsBalanceHidden)
                                      SingleButton(
                                        title: t.wallet_home_screen.edit.fake_balance
                                            .fake_balance_display,
                                        subtitle: t.wallet_home_screen.edit.fake_balance
                                            .fake_balance_description,
                                        subtitleStyle: CoconutTypography.body3_12.setColor(
                                          CoconutColors.gray400,
                                        ),
                                        onPressed: () async {
                                          if (_textFieldFocusNode.hasFocus) {
                                            FocusScope.of(context).unfocus();
                                            return;
                                          }

                                          viewModel.setTempFakeBalanceActive(
                                              !viewModel.tempIsFakeBalanceActive);
                                        },
                                        backgroundColor: Colors.transparent,
                                        rightElement: CupertinoSwitch(
                                          value: viewModel.tempIsFakeBalanceActive,
                                          activeColor: CoconutColors.gray100,
                                          trackColor: CoconutColors.gray600,
                                          thumbColor: CoconutColors.gray800,
                                          onChanged: (value) {
                                            viewModel.setTempFakeBalanceActive(value);
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                                AnimatedCrossFade(
                                  duration: const Duration(milliseconds: 300),
                                  firstChild: const SizedBox.shrink(),
                                  secondChild: Column(
                                    children: [
                                      Container(
                                        height: viewModel.tempIsFakeBalanceActive ? null : 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        child: CoconutTextField(
                                          textInputType:
                                              const TextInputType.numberWithOptions(decimal: true),
                                          textInputFormatter: [
                                            FilteringTextInputFormatter.allow(
                                                RegExp(r'^\d*\.?\d{0,8}')),
                                          ],
                                          placeholderText: viewModel.tempFakeBalanceTotalBtc != null
                                              ? ''
                                              : t.wallet_home_screen.edit.fake_balance
                                                  .fake_balance_input_placeholder,
                                          suffix: _textEditingController.text.isNotEmpty
                                              ? Padding(
                                                  padding: const EdgeInsets.only(
                                                    right: 16,
                                                  ),
                                                  child: Text(
                                                    t.btc,
                                                    style: CoconutTypography.body1_16,
                                                  ),
                                                )
                                              : null,
                                          isLengthVisible: false,
                                          controller: _textEditingController,
                                          focusNode: _textFieldFocusNode,
                                          onChanged: (text) {},
                                          backgroundColor: CoconutColors.black,
                                          errorColor: CoconutColors.hotPink,
                                          placeholderColor: CoconutColors.gray700,
                                          activeColor: CoconutColors.white,
                                          cursorColor: CoconutColors.white,
                                          maxLength: viewModel.maxInputLength,
                                          errorText: _viewModel.inputError ==
                                                  FakeBalanceInputError.exceedsTotalSupply
                                              ? '  ${t.wallet_home_screen.edit.fake_balance.fake_balance_input_exceeds_error}'
                                              : '  ${t.wallet_home_screen.edit.fake_balance.fake_balance_input_not_enough_error(btc: UnitUtil.convertSatoshiToBitcoin(viewModel.minimumSatoshi).toStringAsFixed(8), sats: viewModel.walletItemLength)}',
                                          isError:
                                              _viewModel.inputError != FakeBalanceInputError.none,
                                          maxLines: 1,
                                        ),
                                      ),
                                      CoconutLayout.spacing_400h,
                                    ],
                                  ),
                                  crossFadeState: viewModel.tempIsFakeBalanceActive
                                      ? CrossFadeState.showSecond
                                      : CrossFadeState.showFirst,
                                ),
                              ],
                            );
                          },
                        ),
                        const Divider(
                          height: 1,
                          color: CoconutColors.gray700,
                        ),
                      ],
                      CoconutLayout.spacing_500h,
                      _buildHomeWidgetSelector(),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                top: 0,
                right: 0,
                child: Consumer<WalletHomeEditViewModel>(
                  builder: (context, viewModel, _) {
                    return FixedBottomButton(
                      gradientKey: fixedBottomButtonKey,
                      backgroundColor: CoconutColors.white,
                      isActive: _shouldEnableCompleteButton(),
                      onButtonClicked: () async {
                        FocusScope.of(context).unfocus();
                        if (viewModel.tempIsFakeBalanceActive &&
                            _textEditingController.text.isEmpty) {
                          // 가짜 잔액을 활성화 했지만 금액을 입력하지 않았을 때 -> 0으로 설정할지 다시입력할지 물어봄
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return CoconutPopup(
                                title: t.wallet_home_screen.edit.alert.empty_fake_balance,
                                description:
                                    t.wallet_home_screen.edit.alert.empty_fake_balance_description,
                                leftButtonText: t.wallet_home_screen.edit.alert.enter_again,
                                rightButtonText: t.wallet_home_screen.edit.alert.set_to_0,
                                onTapRight: () async {
                                  viewModel.setTempFakeBalanceTotalBtc(0);

                                  _onComplete();
                                  if (mounted) {
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  }
                                },
                                onTapLeft: () {
                                  Navigator.pop(context);
                                },
                              );
                            },
                          );
                          return;
                        }

                        _onComplete();
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                      text: t.complete,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _shouldEnableCompleteButton() {
    final text = _textEditingController.text;

    final isToggleChanged =
        _viewModel.tempIsFakeBalanceActive != _viewModel.isFakeBalanceActive || // 가짜잔액표시 변동
            _viewModel.tempIsBalanceHidden != _viewModel.isBalanceHidden || // 잔액숨기기 변동
            !_viewModel.tempHomeFeatures.every((tempFeature) {
              // 홈 화면 기능 변동
              final original = _viewModel.homeFeatures.firstWhere(
                (f) => f.homeFeatureTypeString == tempFeature.homeFeatureTypeString,
                orElse: () => tempFeature,
              );
              return tempFeature.isEnabled == original.isEnabled;
            });
    if (_viewModel.tempIsFakeBalanceActive) {
      if (_viewModel.fakeBalanceTotalAmount == null) return true;
      final expectedText = UnitUtil.convertSatoshiToBitcoin(_viewModel.fakeBalanceTotalAmount!)
          .toStringAsFixed(8)
          .replaceFirst(RegExp(r'\.?0*$'), '');
      final isTextChanged = text != expectedText;
      // 가짜 잔액 표시가 활성화 되더라도 입력값이 없으면 변동되지 않음
      if (!isTextChanged) return false;

      final parsed = double.tryParse(text);
      if (parsed != 0 && _viewModel.inputError != FakeBalanceInputError.none) return false;
      return true;
    }
    return isToggleChanged;
  }

  void _onComplete() async {
    if (_textEditingController.text.isEmpty) {}
    await _viewModel.onComplete();
  }

  Widget _buildHomeWidgetSelector() {
    return Consumer<WalletHomeEditViewModel>(
      builder: (context, viewModel, _) {
        final fixedWidgets = [
          {
            'homeFeatureTypeString': HomeFeatureType.totalBalance.toString(),
            'icon': 'assets/svg/piggy-bank.svg'
          },
          {
            'homeFeatureTypeString': HomeFeatureType.walletList.toString(),
            'icon': 'assets/svg/wallet.svg'
          },
        ];
        final displayHomeWidgets = [
          ...fixedWidgets,
          ..._viewModel.tempHomeFeatures.map((e) => {
                'homeFeatureTypeString': e.homeFeatureTypeString,
                'icon': e.assetPath,
                'isEnabled': e.isEnabled,
              })
        ];

        return Center(
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width,
            child: Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 14,
                  children: displayHomeWidgets.map((widget) {
                    return ShrinkAnimationButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        if (fixedWidgets.any((fixed) =>
                            fixed['homeFeatureTypeString'] == widget['homeFeatureTypeString'])) {
                          return;
                        }
                        // homeFeatureTypeString을 통해 토글
                        _viewModel.toggleTempHomeFeatureEnabled(
                            widget['homeFeatureTypeString'].toString());
                      },
                      defaultColor: CoconutColors.gray800,
                      pressedColor: CoconutColors.gray750,
                      child: Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      _getHomeFeatureLabel(
                                          widget['homeFeatureTypeString'].toString()),
                                      style:
                                          CoconutTypography.body3_12.setColor(CoconutColors.white),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: (widget['homeFeatureTypeString'] ==
                                                HomeFeatureType.totalBalance.toString() ||
                                            widget['homeFeatureTypeString'] ==
                                                HomeFeatureType.walletList.toString())
                                        ? Container(
                                            width: 18,
                                            height: 18,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: CoconutColors.gray700,
                                            ),
                                            child: Center(
                                              child: SvgPicture.asset(
                                                'assets/svg/lock.svg',
                                                width: 14,
                                                height: 14,
                                                colorFilter: const ColorFilter.mode(
                                                    CoconutColors.white, BlendMode.srcIn),
                                              ),
                                            ),
                                          )
                                        : AnimatedContainer(
                                            duration: const Duration(milliseconds: 100),
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: (widget['isEnabled'] as bool)
                                                  ? CoconutColors.white
                                                  : CoconutColors.gray800,
                                              border: Border.all(
                                                width: (widget['isEnabled'] as bool) ? 0 : 1.5,
                                                color: CoconutColors.gray600,
                                              ),
                                            ),
                                            child: Center(
                                              child: SvgPicture.asset(
                                                'assets/svg/check.svg',
                                                width: 6,
                                                height: 6,
                                                colorFilter: ColorFilter.mode(
                                                  (widget['isEnabled'] as bool)
                                                      ? CoconutColors.gray800
                                                      : CoconutColors.gray600,
                                                  BlendMode.srcIn,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              SvgPicture.asset(
                                widget['icon']!.toString(),
                                width: 32,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: _fixedBottomButtonSize.height),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getHomeFeatureLabel(String homeFeatureTypeString) {
    final type = HomeFeatureType.values.firstWhere(
      (e) => e.toString() == homeFeatureTypeString,
      orElse: () => HomeFeatureType.totalBalance,
    );

    switch (type) {
      case HomeFeatureType.totalBalance:
        {
          return t.wallet_home_screen.edit.category.total_balance;
        }
      case HomeFeatureType.walletList:
        {
          return t.wallet_home_screen.edit.category.wallet_list;
        }
      case HomeFeatureType.recentTransaction:
        {
          return t.wallet_home_screen.edit.category.recent_transactions;
        }
      case HomeFeatureType.analysis:
        {
          return t.wallet_home_screen.edit.category.analysis;
        }
    }
  }
}
