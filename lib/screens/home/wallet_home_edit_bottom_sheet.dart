import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_home_edit_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/fake_balance_bottom_sheet.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart' show FixedBottomButton;
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
        debugPrint('_fixedBottomButtonSize.height: ${_fixedBottomButtonSize.height}');
      }

      if (_viewModel.fakeBalanceTotalBtc != null) {
        if (_viewModel.fakeBalanceTotalBtc == 0) {
          // 0일 때
          _textEditingController.text = '0';
        } else if (_viewModel.fakeBalanceTotalBtc! % 1 == 0) {
          // 정수일 때
          _textEditingController.text = _viewModel.fakeBalanceTotalBtc.toString().split('.')[0];
        } else {
          _textEditingController.text = _viewModel.fakeBalanceTotalBtc.toString();
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
          _viewModel.setFakeBlancTotalBtc(null);
        }
        try {
          input = double.parse(_textEditingController.text);
        } catch (e) {
          debugPrint(e.toString());
        }

        setState(() {
          _viewModel.setFakeBlancTotalBtc(input);
          if (_viewModel.fakeBalanceTotalBtc == null) {
            _viewModel.setInputError(FakeBalanceInputError.none);
          } else {
            if (_viewModel.fakeBalanceTotalBtc! > 0 &&
                _viewModel.fakeBalanceTotalBtc! <
                    UnitUtil.convertSatoshiToBitcoin(_viewModel.minimumSatoshi)) {
              _viewModel.setInputError(FakeBalanceInputError.notEnoughForAllWallets);
            } else if (_viewModel.fakeBalanceTotalBtc! > _viewModel.maximumAmount) {
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
                                        viewModel.setIsBalanceHidden(!viewModel.isBalanceHidden);
                                      },
                                      backgroundColor: Colors.transparent,
                                      rightElement: CupertinoSwitch(
                                        value: viewModel.isBalanceHidden,
                                        activeColor: CoconutColors.gray100,
                                        trackColor: CoconutColors.gray600,
                                        thumbColor: CoconutColors.gray800,
                                        onChanged: (value) {
                                          viewModel.setIsBalanceHidden(value);
                                        },
                                      ),
                                    ),
                                    if (viewModel.isBalanceHidden)
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

                                          viewModel.setIsFakeBalanceActive(
                                              !viewModel.isFakeBalanceActive);
                                        },
                                        backgroundColor: Colors.transparent,
                                        rightElement: CupertinoSwitch(
                                          value: viewModel.isFakeBalanceActive,
                                          activeColor: CoconutColors.gray100,
                                          trackColor: CoconutColors.gray600,
                                          thumbColor: CoconutColors.gray800,
                                          onChanged: (value) {
                                            viewModel.setIsFakeBalanceActive(value);
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
                                        height: viewModel.isFakeBalanceActive ? null : 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        child: CoconutTextField(
                                          textInputType:
                                              const TextInputType.numberWithOptions(decimal: true),
                                          textInputFormatter: [
                                            FilteringTextInputFormatter.allow(
                                                RegExp(r'^\d*\.?\d{0,8}')),
                                          ],
                                          placeholderText: viewModel.fakeBalanceTotalBtc != null
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
                                  crossFadeState: viewModel.isFakeBalanceActive
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
                child: FixedBottomButton(
                  gradientKey: fixedBottomButtonKey,
                  backgroundColor: CoconutColors.white,
                  isActive: true,
                  onButtonClicked: () async {
                    FocusScope.of(context).unfocus();
                    // setState(() {
                    //   isLoading = true;
                    // });

                    // _onComplete();
                    // if (mounted) {
                    //   Navigator.pop(context);
                    // }
                  },
                  text: t.complete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeWidgetSelector() {
    final widgets = [
      {
        'label': t.wallet_home_screen.edit.category.total_balance,
        'icon': 'assets/svg/piggy-bank.svg'
      },
      {'label': t.wallet_home_screen.edit.category.wallet_list, 'icon': 'assets/svg/wallet.svg'},
      {
        'label': t.wallet_home_screen.edit.category.recent_tramsactions,
        'icon': 'assets/svg/transaction.svg'
      },
      {'label': t.wallet_home_screen.edit.category.analysis, 'icon': 'assets/svg/analysis.svg'},
    ];

    return Center(
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width,
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 14,
              children: widgets.map((widget) {
                const isSelected = true;
                return ShrinkAnimationButton(
                  onPressed: () => debugPrint('onpressed'),
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
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget['label']!,
                                style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                              ),
                              if (widget['label'] ==
                                      t.wallet_home_screen.edit.category.total_balance ||
                                  widget['label'] ==
                                      t.wallet_home_screen.edit.category.wallet_list) ...[
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: CoconutColors.gray750,
                                  ),
                                  child: Center(
                                    child: SvgPicture.asset(
                                      'assets/svg/lock.svg',
                                      width: 14,
                                      height: 14,
                                      colorFilter: const ColorFilter.mode(
                                          CoconutColors.gray700, BlendMode.srcIn),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                const Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: isSelected ? CoconutColors.gray100 : CoconutColors.gray600,
                                ),
                              ],
                            ],
                          ),
                          const Spacer(),
                          SvgPicture.asset(
                            widget['icon']!,
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
  }
}
