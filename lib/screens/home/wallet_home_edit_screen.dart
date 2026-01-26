import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/preference/home_feature.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_home_edit_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

enum FakeBalanceInputError {
  none,
  notEnoughForAllWallets, // 지갑 수만큼 1사토시 이상 배정 불가한 경우
  exceedsTotalSupply, // 2100만 BTC를 초과하는 경우
}

class WalletHomeEditScreen extends StatefulWidget {
  const WalletHomeEditScreen({super.key, required this.scrollController});
  final ScrollController scrollController;

  @override
  State<WalletHomeEditScreen> createState() => _WalletHomeEditScreenState();
}

class _WalletHomeEditScreenState extends State<WalletHomeEditScreen> with TickerProviderStateMixin {
  final TextEditingController _textEditingController = TextEditingController();
  late WalletHomeEditViewModel _viewModel;

  GlobalKey fixedBottomButtonKey = GlobalKey();
  Size _fixedBottomButtonSize = const Size(0, 0);

  final FocusNode _textFieldFocusNode = FocusNode();
  bool _showFakeBalanceInput = false;
  bool _isRenderComplete = false;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 하단 버튼 사이즈 계산
      if (fixedBottomButtonKey.currentContext != null) {
        final fixedBottomButtonRenderBox = fixedBottomButtonKey.currentContext?.findRenderObject() as RenderBox;
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
          // 아주 작은 소수일 때 e-8로 표시되는 경우가 있음 -> toStringAsFixed(8)로 8자리까지 표시 후 뒤에 0이 있으면 제거
          _textEditingController.text = _viewModel.tempFakeBalanceTotalBtc!
              .toStringAsFixed(8)
              .replaceFirst(RegExp(r'\.?0+$'), '');
        }
      }

      if (_viewModel.tempIsFakeBalanceActive) {
        setState(() {
          _showFakeBalanceInput = true;
        });
      }

      _textFieldFocusNode.addListener(() {
        if (_textFieldFocusNode.hasFocus) {
          if (widget.scrollController.hasClients) {
            debugPrint('animateTo: ${_fixedBottomButtonSize.height}');

            widget.scrollController.animateTo(
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
            if (_viewModel.tempFakeBalanceTotalBtc! > _viewModel.maximumAmount) {
              _viewModel.setInputError(FakeBalanceInputError.exceedsTotalSupply);
            } else {
              _viewModel.setInputError(FakeBalanceInputError.none);
            }
          }
        });
      });

      setState(() {
        _isRenderComplete = true;
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
    _viewModel = WalletHomeEditViewModel(context.read<WalletProvider>(), context.read<PreferenceProvider>());
    return _viewModel;
  }

  void _onFakeBalanceToggleChanged(bool value) {
    if (value) {
      setState(() {
        _showFakeBalanceInput = true;
      });
    } else {
      setState(() {
        _showFakeBalanceInput = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<WalletProvider, PreferenceProvider, WalletHomeEditViewModel>(
      create: (context) => _createViewModel(),
      update: (context, walletProvider, preferenceProvider, previous) {
        previous ??= _createViewModel();
        previous.onPreferenceProviderUpdated();
        return previous..onWalletProviderUpdated(walletProvider);
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: CoconutAppBar.build(
            backgroundColor: CoconutColors.black,
            context: context,
            isBottom: true,
            onBackPressed: () {
              if (_shouldEnableCompleteButton()) {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return CoconutPopup(
                      languageCode: context.read<PreferenceProvider>().language,
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
          body: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: MediaQuery.sizeOf(context).height,
                    color: CoconutColors.black,
                    child: SingleChildScrollView(
                      controller: widget.scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CoconutLayout.spacing_100h,
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                            child: SizedBox(
                              width: MediaQuery.sizeOf(context).width / 3 * 2,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(t.wallet_home_screen.edit.title, style: CoconutTypography.heading3_21_Bold),
                              ),
                            ),
                          ),
                          const Divider(height: 1, color: CoconutColors.gray700),
                          if (context.read<WalletProvider>().walletItemList.isNotEmpty) ...[
                            Consumer<WalletHomeEditViewModel>(
                              builder: (context, viewModel, child) {
                                return Column(
                                  children: [
                                    SingleButton(
                                      isVerticalSubtitle: true,
                                      title: t.wallet_home_screen.edit.hide_balance,
                                      subtitle: t.wallet_home_screen.edit.hide_balance_on_home,
                                      subtitleStyle: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                                      customPadding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                                      onPressed: () async {
                                        if (_textFieldFocusNode.hasFocus) {
                                          FocusScope.of(context).unfocus();
                                          return;
                                        }
                                        viewModel.setTempIsBalanceHidden(!viewModel.tempIsBalanceHidden);
                                      },
                                      betweenGap: 16,
                                      backgroundColor: CoconutColors.black,
                                      rightElement: CoconutSwitch(
                                        isOn: viewModel.tempIsBalanceHidden,
                                        scale: 0.7,
                                        activeColor: CoconutColors.gray100,
                                        trackColor: CoconutColors.gray600,
                                        thumbColor: CoconutColors.gray800,
                                        onChanged: (value) {
                                          viewModel.setTempIsBalanceHidden(value);
                                        },
                                      ),
                                    ),
                                    SingleButton(
                                      isVerticalSubtitle: true,
                                      title: t.wallet_home_screen.edit.fake_balance.fake_balance_display,
                                      subtitle: t.wallet_home_screen.edit.fake_balance.fake_balance_input_description,
                                      subtitleStyle: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                                      customPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                                      betweenGap: 16,
                                      onPressed: () async {
                                        if (_textFieldFocusNode.hasFocus) {
                                          FocusScope.of(context).unfocus();
                                          return;
                                        }

                                        viewModel.setTempFakeBalanceActive(!viewModel.tempIsFakeBalanceActive);
                                        _onFakeBalanceToggleChanged(viewModel.tempIsFakeBalanceActive);
                                      },
                                      backgroundColor: Colors.transparent,
                                      rightElement: CoconutSwitch(
                                        isOn: viewModel.tempIsFakeBalanceActive,
                                        scale: 0.7,
                                        activeColor: CoconutColors.gray100,
                                        trackColor: CoconutColors.gray600,
                                        thumbColor: CoconutColors.gray800,
                                        onChanged: (value) {
                                          viewModel.setTempFakeBalanceActive(value);
                                          _onFakeBalanceToggleChanged(value);
                                        },
                                      ),
                                    ),
                                    _buildDelayedFakeBalanceInput(),
                                    SingleButton(
                                      isVerticalSubtitle: true,
                                      title: t.wallet_home_screen.edit.hide_fiat_price,
                                      subtitle: t.wallet_home_screen.edit.hide_fiat_price_on_home,
                                      subtitleStyle: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                                      customPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                                      onPressed: () async {
                                        if (_textFieldFocusNode.hasFocus) {
                                          FocusScope.of(context).unfocus();
                                          return;
                                        }
                                        viewModel.setTempIsFiatBalanceHidden(!viewModel.tempIsFiatBalanceHidden);
                                      },
                                      betweenGap: 16,
                                      backgroundColor: CoconutColors.black,
                                      rightElement: CoconutSwitch(
                                        isOn: viewModel.tempIsFiatBalanceHidden,
                                        scale: 0.7,
                                        activeColor: CoconutColors.gray100,
                                        trackColor: CoconutColors.gray600,
                                        thumbColor: CoconutColors.gray800,
                                        onChanged: (value) {
                                          viewModel.setTempIsFiatBalanceHidden(value);
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const Divider(height: 1, color: CoconutColors.gray700),
                          ],
                          CoconutLayout.spacing_500h,
                          _buildHomeWidgetSelector(),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -MediaQuery.of(context).viewInsets.bottom,
                  child: SizedBox(
                    height: 800,
                    child: Consumer<WalletHomeEditViewModel>(
                      builder: (context, viewModel, _) {
                        return FixedBottomButton(
                          gradientKey: fixedBottomButtonKey,
                          backgroundColor: CoconutColors.white,
                          isActive: _shouldEnableCompleteButton(),
                          onButtonClicked: () async {
                            FocusScope.of(context).unfocus();
                            if (viewModel.tempIsFakeBalanceActive && _textEditingController.text.isEmpty) {
                              // 가짜 잔액을 활성화 했지만 금액을 입력하지 않았을 때 -> 0으로 설정할지 다시입력할지 물어봄
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return CoconutPopup(
                                    languageCode: context.read<PreferenceProvider>().language,
                                    title: t.wallet_home_screen.edit.alert.empty_fake_balance,
                                    description: t.wallet_home_screen.edit.alert.empty_fake_balance_description,
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
                ),
              ],
            ),
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
        _viewModel.tempIsFiatBalanceHidden != _viewModel.isFiatBalanceHidden || // 법정화폐잔액숨기기 변동
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
      final expectedText = UnitUtil.convertSatoshiToBitcoin(
        _viewModel.fakeBalanceTotalAmount!,
      ).toStringAsFixed(8).replaceFirst(RegExp(r'\.?0*$'), '');
      final isTextChanged = text != expectedText;
      // 가짜 잔액 표시가 활성화 되더라도 입력값이 없으면 변동되지 않음
      if (!isTextChanged) return isToggleChanged;

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
          {'homeFeatureTypeString': HomeFeatureType.totalBalance.name, 'icon': HomeFeatureType.totalBalance.assetPath},
          {'homeFeatureTypeString': HomeFeatureType.walletList.name, 'icon': HomeFeatureType.walletList.assetPath},
        ];
        final displayHomeWidgets = [
          ...fixedWidgets,
          ..._viewModel.tempHomeFeatures.map(
            (e) => {
              'homeFeatureTypeString': e.homeFeatureTypeString,
              'icon':
                  HomeFeatureType.values
                      .firstWhere(
                        (type) => type.name == e.homeFeatureTypeString,
                        orElse: () => HomeFeatureType.totalBalance,
                      )
                      .assetPath,
              'isEnabled': e.isEnabled,
            },
          ),
        ];
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            width: MediaQuery.sizeOf(context).width,
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    // 한 줄에 몇 개 들어갈지 계산 (예: 3개)
                    double spacing = 12;
                    int itemsPerRow = 3;

                    // 각 아이템의 너비 계산 (spacing과 패딩을 제외하고 가득 차도록 설정)
                    double itemWidth = (constraints.maxWidth - spacing * (itemsPerRow - 1)) / itemsPerRow;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: 14,
                      children:
                          displayHomeWidgets.map((widget) {
                            return SizedBox(
                              width: itemWidth,
                              height: itemWidth,
                              child: ShrinkAnimationButton(
                                isActive:
                                    !fixedWidgets.any(
                                      (fixed) => fixed['homeFeatureTypeString'] == widget['homeFeatureTypeString'],
                                    ),
                                onPressed: () {
                                  FocusScope.of(context).unfocus();
                                  // homeFeatureTypeString을 통해 토글
                                  _viewModel.toggleTempHomeFeatureEnabled(widget['homeFeatureTypeString'].toString());
                                },
                                defaultColor: CoconutColors.gray800,
                                pressedColor: CoconutColors.gray750,
                                child: Container(
                                  height: 100,
                                  width: 100,
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Stack(
                                          children: [
                                            Align(
                                              alignment: Alignment.topLeft,
                                              child: MediaQuery(
                                                data: MediaQuery.of(
                                                  context,
                                                ).copyWith(textScaler: const TextScaler.linear(1.0)),
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerLeft,
                                                  child: Text(
                                                    _getHomeFeatureLabel(widget['homeFeatureTypeString'].toString()),
                                                    maxLines: 2,
                                                    style: CoconutTypography.body2_14.setColor(CoconutColors.white),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Align(
                                              alignment: Alignment.topRight,
                                              child:
                                                  (widget['homeFeatureTypeString'] ==
                                                              HomeFeatureType.totalBalance.name ||
                                                          widget['homeFeatureTypeString'] ==
                                                              HomeFeatureType.walletList.name)
                                                      ? Container(
                                                        width: 16,
                                                        height: 16,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: CoconutColors.gray700.withValues(alpha: 0.5),
                                                        ),
                                                        child: Center(
                                                          child: SvgPicture.asset(
                                                            'assets/svg/check.svg',
                                                            width: 6,
                                                            height: 6,
                                                            colorFilter: const ColorFilter.mode(
                                                              CoconutColors.gray800,
                                                              BlendMode.srcIn,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                      : AnimatedContainer(
                                                        duration: const Duration(milliseconds: 100),
                                                        width: 16,
                                                        height: 16,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color:
                                                              (widget['isEnabled'] as bool)
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
                                        SvgPicture.asset(widget['icon']!.toString(), width: 32),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    );
                  },
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
      (e) => e.name == homeFeatureTypeString,
      orElse: () => HomeFeatureType.totalBalance,
    );
    if (type == HomeFeatureType.totalBalance) {
      return t.wallet_home_screen.edit.category.total_balance;
    } else if (type == HomeFeatureType.walletList) {
      return t.wallet_home_screen.edit.category.wallet_list;
    } else if (type == HomeFeatureType.recentTransaction) {
      return t.wallet_home_screen.edit.category.recent_transactions;
    } else if (type == HomeFeatureType.analysis) {
      return t.wallet_home_screen.edit.category.analysis;
    }

    return '';
  }

  Widget _buildDelayedFakeBalanceInput() {
    return Consumer<WalletHomeEditViewModel>(
      builder: (context, viewModel, child) {
        if (!_isRenderComplete) {
          return const SizedBox(height: 12);
        }
        return AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          firstChild: const SizedBox(height: 0),
          secondChild: Column(
            children: [
              Container(
                height: viewModel.tempIsFakeBalanceActive ? null : 0,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CoconutTextField(
                  textInputType: const TextInputType.numberWithOptions(decimal: true),
                  textInputFormatter: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,8}'))],
                  placeholderText:
                      viewModel.tempFakeBalanceTotalBtc != null
                          ? ''
                          : t.wallet_home_screen.edit.fake_balance.fake_balance_input_placeholder,
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
                  errorText:
                      _viewModel.inputError == FakeBalanceInputError.exceedsTotalSupply
                          ? '  ${t.wallet_home_screen.edit.fake_balance.fake_balance_input_exceeds_error}'
                          : '',
                  isError: _viewModel.inputError != FakeBalanceInputError.none,
                  maxLines: 1,
                ),
              ),
              CoconutLayout.spacing_400h,
            ],
          ),
          crossFadeState: viewModel.tempIsFakeBalanceActive ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        );
      },
    );
  }
}
