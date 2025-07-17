import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/fake_balance_bottom_sheet.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/material.dart';

class WalletHomeEditViewModel extends ChangeNotifier {
  WalletProvider _walletProvider;
  late final PreferenceProvider _preferenceProvider;
  late bool _isBalanceHidden;
  late bool _isFakeBalanceActive;

  late int minimumSatoshi;
  final int maximumAmount = 21000000;
  final int maxInputLength = 17; // 21000000.00000000

  Map<int, AnimatedBalanceData> _walletBalance = {};
  Map<int, dynamic> _fakeBalanceMap = {};
  int? _fakeBalanceTotalAmount;
  double? _fakeBalanceTotalBtc;
  String? _fakeBalanceText;
  FakeBalanceInputError _inputError = FakeBalanceInputError.none;

  WalletHomeEditViewModel(
    this._walletProvider,
    this._preferenceProvider,
  ) {
    _walletBalance = _walletProvider
        .fetchWalletBalanceMap()
        .map((key, balance) => MapEntry(key, AnimatedBalanceData(balance.total, balance.total)));
    minimumSatoshi = _walletProvider.walletItemList.length;
    _isBalanceHidden = _preferenceProvider.isBalanceHidden;
    _isFakeBalanceActive = _preferenceProvider.isFakeBalanceActive;
    _fakeBalanceTotalAmount = _preferenceProvider.fakeBalanceTotalAmount;
    _fakeBalanceMap = _preferenceProvider.getFakeBalanceMap();

    _fakeBalanceTotalBtc = _preferenceProvider.fakeBalanceTotalAmount != null
        ? UnitUtil.convertSatoshiToBitcoin(_preferenceProvider.fakeBalanceTotalAmount!)
        : null;
    if (_fakeBalanceTotalBtc != null) {
      if (_fakeBalanceTotalBtc == 0) {
        // 0일 때
        _fakeBalanceText = '0';
      } else if (_fakeBalanceTotalBtc! % 1 == 0) {
        // 정수일 때
        _fakeBalanceText = _fakeBalanceTotalBtc.toString().split('.')[0];
      } else {
        _fakeBalanceText = _fakeBalanceTotalBtc.toString();
      }
    }
  }

  bool get isBalanceHidden => _isBalanceHidden;
  bool get isFakeBalanceActive => _isFakeBalanceActive;
  int? get fakeBalanceTotalAmount => _fakeBalanceTotalAmount;
  double? get fakeBalanceTotalBtc => _fakeBalanceTotalBtc;
  String? get fakeBalanceText => _fakeBalanceText;
  Map<int, dynamic> get fakeBalanceMap => _fakeBalanceMap;
  int get walletItemLength => _walletProvider.walletItemList.length;
  FakeBalanceInputError get inputError => _inputError;

  void onWalletProviderUpdated(WalletProvider walletProvider) {
    _walletProvider = walletProvider;
    notifyListeners();
  }

  void onPreferenceProviderUpdated() {
    /// 잔액 숨기기 변동 체크
    if (_isBalanceHidden != _preferenceProvider.isBalanceHidden) {
      setIsBalanceHidden(_preferenceProvider.isBalanceHidden);
    }

    /// 가짜 잔액 총량 변동 체크 (on/off 판별)
    if (_fakeBalanceTotalAmount != _preferenceProvider.fakeBalanceTotalAmount) {
      _setFakeBlancTotalAmount(_preferenceProvider.fakeBalanceTotalAmount);
      _setFakeBlanceMap(_preferenceProvider.getFakeBalanceMap());
    }
    notifyListeners();
  }

  void setIsBalanceHidden(bool value) {
    _preferenceProvider.changeIsBalanceHidden(value);
    _isBalanceHidden = value;
    if (!value) clearFakeBlanceTotalAmount();
    notifyListeners();
  }

  void clearFakeBlanceTotalAmount() {
    _preferenceProvider.clearFakeBalanceTotalAmount();
    _preferenceProvider.changeIsFakeBalanceActive(false);
    _isFakeBalanceActive = false;
    notifyListeners();
  }

  void setIsFakeBalanceActive(bool value) {
    _preferenceProvider.changeIsFakeBalanceActive(value);
    _isFakeBalanceActive = value;
    notifyListeners();
  }

  void _setFakeBlancTotalAmount(int? value) {
    _fakeBalanceTotalAmount = value;
    notifyListeners();
  }

  void _setFakeBlanceMap(Map<int, dynamic> value) {
    _fakeBalanceMap = value;
    notifyListeners();
  }

  void setFakeBlancTotalBtc(double? value) {
    _fakeBalanceTotalBtc = value;
    notifyListeners();
  }

  void setInputError(FakeBalanceInputError error) {
    _inputError = error;
    notifyListeners();
  }

  int? getFakeTotalBalance() {
    return _fakeBalanceTotalAmount;
  }
}
