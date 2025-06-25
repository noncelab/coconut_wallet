import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

enum FakeBalanceInputError {
  none,
  notEnoughForAllWallets, // 지갑 수만큼 1사토시 이상 배정 불가한 경우
  exceedsTotalSupply, // 2100만 BTC를 초과하는 경우
}

class FakeBalanceBottomSheet extends StatefulWidget {
  const FakeBalanceBottomSheet({super.key});

  @override
  State<FakeBalanceBottomSheet> createState() => _FakeBalanceBottomSheetState();
}

class _FakeBalanceBottomSheetState extends State<FakeBalanceBottomSheet> {
  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  double? _fakeBalanceTotalAmount;
  FakeBalanceInputError _inputError = FakeBalanceInputError.none;

  late final WalletProvider _walletProvider;
  late double _minimumAmount;
  final double _maximumAmount = 21000000;
  final int _maxInputLength = 17; // 21000000.00000000

  @override
  void initState() {
    super.initState();
    _fakeBalanceTotalAmount = context.read<PreferenceProvider>().fakeBalanceTotalAmount;
    _walletProvider = Provider.of<WalletProvider>(context, listen: false);
    _minimumAmount = 0.00000001 * _walletProvider.walletItemList.length;
    if (_fakeBalanceTotalAmount != null) {
      if (_fakeBalanceTotalAmount == 0) {
        _textEditingController.text = '0';
      } else {
        _textEditingController.text = _fakeBalanceTotalAmount.toString();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // setState(() {
      //   // description text를 출력하기 위해 setState
      //   _textFieldFocusNode.requestFocus();
      // });

      _textEditingController.addListener(() {
        double input;
        try {
          input = double.parse(_textEditingController.text);
        } catch (e) {
          return;
        }
        final int inputSats = (input * 100000000).round();
        final int minSats = (_minimumAmount * 100000000).round();

        if (inputSats > 0 && inputSats < minSats) {
          setState(() {
            _inputError = FakeBalanceInputError.notEnoughForAllWallets;
          });
        } else if (input > _maximumAmount) {
          setState(() {
            _inputError = FakeBalanceInputError.exceedsTotalSupply;
          });
        } else {
          setState(() {
            _inputError = FakeBalanceInputError.none;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<PreferenceProvider, bool>(
      selector: (_, viewModel) => viewModel.isBalanceHidden,
      builder: (context, isBalanceHidden, child) {
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: CoconutColors.black,
            appBar: CoconutAppBar.buildWithNext(
              title: t.settings_screen.fake_balance.fake_balance_setting,
              context: context,
              isBottom: true,
              isActive: (_textEditingController.text.isNotEmpty) &&
                  (double.parse(_textEditingController.text) == 0 ||
                      _inputError == FakeBalanceInputError.none),
              nextButtonTitle: t.complete,
              usePrimaryActiveColor: true,
              onNextPressed: () => {},
            ),
            body: Padding(
              padding: const EdgeInsets.only(left: Sizes.size16, right: Sizes.size16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.settings_screen.fake_balance.fake_balance_display,
                        style: CoconutTypography.body2_14_Bold.setColor(
                          CoconutColors.white,
                        ),
                      ),
                      CupertinoSwitch(
                        value: isBalanceHidden,
                        activeColor: CoconutColors.gray100,
                        trackColor: CoconutColors.gray600,
                        thumbColor: CoconutColors.gray800,
                        onChanged: (value) {
                          final viewModel = context.read<PreferenceProvider>();
                          viewModel.changeIsBalanceHidden(value);
                          viewModel.clearFakeBalanceTotalAmount();
                        },
                      ),
                    ],
                  ),
                  CoconutLayout.spacing_600h,
                  Visibility(
                    visible: isBalanceHidden,
                    child: CoconutTextField(
                      textInputType: const TextInputType.numberWithOptions(decimal: true),
                      textInputFormatter: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,8}')),
                      ],
                      placeholderText:
                          t.settings_screen.fake_balance.fake_balance_input_placeholder,
                      descriptionText: _textFieldFocusNode.hasFocus
                          ? '  ${t.settings_screen.fake_balance.fake_balance_input_description}'
                          : '',
                      isLengthVisible: false,
                      controller: _textEditingController,
                      focusNode: _textFieldFocusNode,
                      onChanged: (text) {},
                      backgroundColor: CoconutColors.white.withOpacity(0.15),
                      errorColor: CoconutColors.hotPink,
                      placeholderColor: CoconutColors.gray700,
                      activeColor: CoconutColors.white,
                      cursorColor: CoconutColors.white,
                      maxLength: _maxInputLength,
                      errorText: _inputError == FakeBalanceInputError.exceedsTotalSupply
                          ? '  ${t.settings_screen.fake_balance.fake_balance_input_exceeds_error}'
                          : '  ${t.settings_screen.fake_balance.fake_balance_input_not_enough_error(btc: _minimumAmount.toStringAsFixed(8), sats: _walletProvider.walletItemList.length)}',
                      isError: _inputError != FakeBalanceInputError.none,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
