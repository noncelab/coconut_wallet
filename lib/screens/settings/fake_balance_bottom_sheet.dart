import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/overlays/coconut_loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

enum FakeBalanceInputError {
  none,
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
  double? _fakeBalanceTotalBtc;
  FakeBalanceInputError _inputError = FakeBalanceInputError.none;

  late final WalletProvider _walletProvider;
  late final PreferenceProvider _preferenceProvider;
  final int _maximumAmount = 21000000;
  final int _maxInputLength = 17; // 21000000.00000000

  bool isLoading = false;
  late bool _isFakeBalanceActive;

  @override
  void initState() {
    super.initState();
    _preferenceProvider = context.read<PreferenceProvider>();
    _fakeBalanceTotalBtc =
        _preferenceProvider.fakeBalanceTotalAmount != null
            ? UnitUtil.convertSatoshiToBitcoin(_preferenceProvider.fakeBalanceTotalAmount!)
            : null;
    _isFakeBalanceActive = _preferenceProvider.isFakeBalanceActive;

    _walletProvider = Provider.of<WalletProvider>(context, listen: false);
    if (_fakeBalanceTotalBtc != null) {
      if (_fakeBalanceTotalBtc == 0) {
        // 0일 때
        _textEditingController.text = '0';
      } else if (_fakeBalanceTotalBtc! % 1 == 0) {
        // 정수일 때
        _textEditingController.text = _fakeBalanceTotalBtc.toString().split('.')[0];
      } else {
        // 아주 작은 소수일 때 e-8로 표시되는 경우가 있음 -> toStringAsFixed(8)로 8자리까지 표시 후 뒤에 0이 있으면 제거
        _textEditingController.text = _fakeBalanceTotalBtc!.toStringAsFixed(8).replaceFirst(RegExp(r'\.?0+$'), '');
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textEditingController.addListener(() {
        double? input;
        if (_textEditingController.text.isEmpty) {
          _fakeBalanceTotalBtc = null;
        }

        if (_textEditingController.text.length > 1 &&
            _textEditingController.text[0] == '0' &&
            _textEditingController.text[1] == '0' &&
            !_textEditingController.text.contains('.')) {
          // 정수 자리의 첫번째가 0인 경우 0의 추가 입력을 막음
          _textEditingController.text = _textEditingController.text.substring(1);
          _textEditingController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textEditingController.text.length),
          );
        }

        try {
          input = double.parse(_textEditingController.text);
        } catch (e) {
          debugPrint(e.toString());
        }

        setState(() {
          _fakeBalanceTotalBtc = input;
          if (_fakeBalanceTotalBtc == null) {
            _inputError = FakeBalanceInputError.none;
          } else {
            if (_fakeBalanceTotalBtc! > _maximumAmount) {
              _inputError = FakeBalanceInputError.exceedsTotalSupply;
            } else {
              _inputError = FakeBalanceInputError.none;
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: CoconutColors.black,
        appBar: CoconutAppBar.build(
          title: t.settings_screen.fake_balance.fake_balance_setting,
          context: context,
          isBottom: true,
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 25),
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              t.settings_screen.fake_balance.fake_balance_display,
                              style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: CoconutSwitch(
                                isOn: _isFakeBalanceActive,
                                activeColor: CoconutColors.gray100,
                                trackColor: CoconutColors.gray600,
                                thumbColor: CoconutColors.gray800,
                                onChanged: (value) {
                                  setState(() {
                                    _isFakeBalanceActive = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        CoconutLayout.spacing_600h,
                        Visibility(
                          visible: _isFakeBalanceActive,
                          child: CoconutTextField(
                            textInputType: const TextInputType.numberWithOptions(decimal: true),
                            textInputFormatter: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,8}'))],
                            placeholderText:
                                _fakeBalanceTotalBtc != null
                                    ? ''
                                    : t.settings_screen.fake_balance.fake_balance_input_placeholder,
                            descriptionText:
                                _textFieldFocusNode.hasFocus
                                    ? '  ${t.settings_screen.fake_balance.fake_balance_input_description}'
                                    : '',
                            suffix:
                                _textEditingController.text.isNotEmpty
                                    ? Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: Text(t.btc, style: CoconutTypography.body1_16),
                                    )
                                    : null,
                            isLengthVisible: false,
                            controller: _textEditingController,
                            focusNode: _textFieldFocusNode,
                            onChanged: (text) {},
                            backgroundColor: CoconutColors.white.withValues(alpha: 0.15),
                            errorColor: CoconutColors.hotPink,
                            placeholderColor: CoconutColors.gray700,
                            activeColor: CoconutColors.white,
                            cursorColor: CoconutColors.white,
                            maxLength: _maxInputLength,
                            errorText:
                                _inputError == FakeBalanceInputError.exceedsTotalSupply
                                    ? '  ${t.settings_screen.fake_balance.fake_balance_input_exceeds_error}'
                                    : '',
                            isError: _inputError != FakeBalanceInputError.none,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CoconutButton(
                    backgroundColor: CoconutColors.white,
                    isActive: _shouldEnableCompleteButton(),
                    onPressed: () async {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        isLoading = true;
                      });

                      _onComplete();
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    },
                    text: t.complete,
                  ),
                  CoconutLayout.spacing_800h,
                ],
              ),
            ),
            if (isLoading) const CoconutLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  bool _shouldEnableCompleteButton() {
    if (isLoading) return false;
    if (_textEditingController.text.isEmpty) return false;

    final text = _textEditingController.text;
    final isToggleChanged = _isFakeBalanceActive != _preferenceProvider.isFakeBalanceActive;

    if (_preferenceProvider.fakeBalanceTotalAmount == null) {
      return isToggleChanged;
    }
    // satoshi를 BTC로 변환
    double fakeBalanceTotalAmount = (_preferenceProvider.fakeBalanceTotalAmount ?? 0) / 100000000;

    if (_isFakeBalanceActive) {
      // text가 "0"일 때와 fakeBalanceTotalAmount가 0일 때를 동일하게 처리
      // text를 double로 파싱해서 비교
      final textAsDouble = double.tryParse(text) ?? 0;
      final isTextChanged = textAsDouble != fakeBalanceTotalAmount;

      if (text.isEmpty || !isTextChanged) return false;

      final parsed = double.tryParse(text);
      if (parsed != 0 && _inputError != FakeBalanceInputError.none) return false;
      return true;
    } else {
      return isToggleChanged;
    }
  }

  void _onComplete() async {
    final wallets = _walletProvider.walletItemList;
    if (!_isFakeBalanceActive) {
      await _preferenceProvider.toggleFakeBalanceActivation(false);
      return;
    }
    if (_fakeBalanceTotalBtc == null || wallets.isEmpty) return;

    // fake balance 토글 상태 변경 시 상태 업데이트
    if (_preferenceProvider.isFakeBalanceActive != _isFakeBalanceActive) {
      await _preferenceProvider.toggleFakeBalanceActivation(_isFakeBalanceActive);
    }

    final isFakeBalanceActive = _preferenceProvider.isFakeBalanceActive;
    _preferenceProvider.distributeFakeBalance(
      wallets,
      isFakeBalanceActive: isFakeBalanceActive,
      fakeBalanceTotalSats: UnitUtil.convertBitcoinToSatoshi(_fakeBalanceTotalBtc!.toDouble()).toDouble(),
    );
  }
}
