import 'dart:math';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/overlays/coconut_loading_overlay.dart';
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
  late final PreferenceProvider _preferenceProvider;
  late double _minimumAmount;
  final double _maximumAmount = 21000000;
  final int _maxInputLength = 17; // 21000000.00000000

  bool isLoading = false;
  late bool _isFakeBalanceActive;

  @override
  void initState() {
    super.initState();
    _preferenceProvider = context.read<PreferenceProvider>();
    _fakeBalanceTotalAmount = _preferenceProvider.fakeBalanceTotalAmount;
    _isFakeBalanceActive = _preferenceProvider.isFakeBalanceActive;
    _walletProvider = Provider.of<WalletProvider>(context, listen: false);
    _minimumAmount = 0.00000001 * _walletProvider.walletItemList.length;
    if (_fakeBalanceTotalAmount != null) {
      if (_fakeBalanceTotalAmount == 0) {
        // 0일 때
        _textEditingController.text = '0';
      } else if (_fakeBalanceTotalAmount! % 1 == 0) {
        // 정수일 때
        _textEditingController.text = _fakeBalanceTotalAmount.toString().split('.')[0];
      } else {
        _textEditingController.text = _fakeBalanceTotalAmount.toString();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textEditingController.addListener(() {
        double? input;
        if (_textEditingController.text.isEmpty) {
          _fakeBalanceTotalAmount = null;
        }
        try {
          input = double.parse(_textEditingController.text);
        } catch (e) {
          debugPrint(e.toString());
        }

        setState(() {
          _fakeBalanceTotalAmount = input;
          if (_fakeBalanceTotalAmount == null) {
            _inputError = FakeBalanceInputError.none;
          } else {
            final int inputSats = (_fakeBalanceTotalAmount! * 100000000).round();
            final int minSats = (_minimumAmount * 100000000).round();

            if (inputSats > 0 && inputSats < minSats) {
              _inputError = FakeBalanceInputError.notEnoughForAllWallets;
            } else if (_fakeBalanceTotalAmount! > _maximumAmount) {
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
                              style: CoconutTypography.body2_14_Bold.setColor(
                                CoconutColors.white,
                              ),
                            ),
                            CupertinoSwitch(
                              value: _isFakeBalanceActive,
                              activeColor: CoconutColors.gray100,
                              trackColor: CoconutColors.gray600,
                              thumbColor: CoconutColors.gray800,
                              onChanged: (value) {
                                setState(() {
                                  _isFakeBalanceActive = value;
                                });
                              },
                            ),
                          ],
                        ),
                        CoconutLayout.spacing_600h,
                        Visibility(
                          visible: _isFakeBalanceActive,
                          child: CoconutTextField(
                            textInputType: const TextInputType.numberWithOptions(decimal: true),
                            textInputFormatter: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,8}')),
                            ],
                            placeholderText: _fakeBalanceTotalAmount != null
                                ? ''
                                : t.settings_screen.fake_balance.fake_balance_input_placeholder,
                            descriptionText: _textFieldFocusNode.hasFocus
                                ? '  ${t.settings_screen.fake_balance.fake_balance_input_description}'
                                : '',
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
            if (isLoading) const CoconutLoadingOverlay()
          ],
        ),
      ),
    );
  }

  bool _shouldEnableCompleteButton() {
    if (isLoading) return false;

    final text = _textEditingController.text;
    final isTextChanged = text != _preferenceProvider.fakeBalanceTotalAmount.toString();
    final isToggleChanged = _isFakeBalanceActive != _preferenceProvider.isFakeBalanceActive;

    if (_isFakeBalanceActive) {
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
      await _preferenceProvider.changeIsFakeBalanceActive(false);
      return;
    }
    if (_fakeBalanceTotalAmount == null || wallets.isEmpty) return;

    if (_fakeBalanceTotalAmount == 0) {
      await _preferenceProvider.setFakeBalanceTotalAmount(_fakeBalanceTotalAmount!);

      final Map<int, dynamic> fakeBalanceMap = {};
      for (int i = 0; i < wallets.length; i++) {
        final walletId = wallets[i].id;

        fakeBalanceMap[walletId] = 0.0;
        debugPrint('[Wallet $i]Fake Balance: ${fakeBalanceMap[i]} BTC');
      }
      await _preferenceProvider.setFakeBalanceMap(fakeBalanceMap);
      return;
    }

    final totalSats = (_fakeBalanceTotalAmount! * 100000000).round();
    final walletCount = wallets.length;

    if (totalSats < walletCount) return; // 최소 1사토시씩 못 주면 리턴

    final random = Random();
    // 1. 각 지갑에 최소 1사토시 할당
    // 2. 남은 사토시를 랜덤 가중치로 분배
    final List<int> weights = List.generate(walletCount, (_) => random.nextInt(100) + 1); // 1~100
    final int weightSum = weights.reduce((a, b) => a + b);
    final int remainingSats = totalSats - walletCount;
    final List<int> splits = [];

    for (int i = 0; i < walletCount; i++) {
      final int share = (remainingSats * weights[i] / weightSum).floor();
      splits.add(1 + share); // 최소 1 사토시 보장
    }

    // 보정: 분할의 총합이 totalSats보다 작을 수 있으므로 마지막 지갑에 부족분 추가
    final int diff = totalSats - splits.reduce((a, b) => a + b);
    splits[splits.length - 1] += diff;

    final fakeBalances = splits.map((sats) => sats / 100000000).toList();
    final Map<int, dynamic> fakeBalanceMap = {};

    if (_preferenceProvider.isFakeBalanceActive != _isFakeBalanceActive) {
      await _preferenceProvider.changeIsFakeBalanceActive(_isFakeBalanceActive);
    }

    await _preferenceProvider.setFakeBalanceTotalAmount(_fakeBalanceTotalAmount!);

    for (int i = 0; i < fakeBalances.length; i++) {
      final walletId = wallets[i].id;
      final fakeBalance = fakeBalances[i];
      fakeBalanceMap[walletId] = fakeBalance;
      debugPrint('[Wallet $i]Fake Balance: ${fakeBalances[i]} BTC');
    }

    await _preferenceProvider.setFakeBalanceMap(fakeBalanceMap);
  }
}
