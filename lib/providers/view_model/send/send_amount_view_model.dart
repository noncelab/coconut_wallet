import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';

class SendAmountViewModel extends ChangeNotifier {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;
  late bool? _isNetworkOn;
  late int _confirmedBalance;
  late int _unconfirmedBalance;
  late String _input;
  late bool _isNextButtonEnabled;
  int? _errorIndex;
  SendAmountViewModel(
      this._sendInfoProvider, this._walletProvider, this._isNetworkOn) {
    var wallet = _walletProvider.getWalletById(_sendInfoProvider.walletId!);
    _confirmedBalance = wallet.walletFeature.getBalance();
    _unconfirmedBalance = wallet.walletFeature.getUnconfirmedBalance();
    _input = '';
    _isNextButtonEnabled = false;
  }
  int get confirmedBalance => _confirmedBalance;
  int? get errorIndex => _errorIndex;
  String get input => _input;
  bool get isNetworkOn => _isNetworkOn == true;
  bool get isNextButtonEnabled => _isNextButtonEnabled;
  int get unconfirmedBalance => _unconfirmedBalance;

  void onKeyTap(String newInput) {
    if (newInput == '<') {
      if (_input.isNotEmpty) {
        _input = _input.substring(0, _input.length - 1);
      }
    } else if (newInput == '.') {
      if (_input.isEmpty) {
        _input = '0.';
      } else {
        if (!_input.contains('.')) {
          _input += newInput;
        }
      }
    } else {
      if (_input.isEmpty) {
        /// 첫 입력이 0인 경우는 바로 추가
        if (newInput == '0') {
          _input += newInput;
        } else if (newInput != '0' || _input.contains('.')) {
          _input += newInput;
        }
      } else if (_input == '0' && newInput != '.') {
        /// 첫 입력이 0이고, 그 후 0이 아닌 숫자가 올 경우에는 기존 0을 대체
        _input = newInput;
      } else if (_input.contains('.')) {
        /// 소수점 이후 숫자가 8자리 이하인 경우 추가
        int decimalIndex = _input.indexOf('.');
        if (_input.length - decimalIndex <= 8) {
          _input += newInput;
        }
      } else {
        /// 일반적인 경우 추가
        _input += newInput;
      }
    }

    if (_input.isNotEmpty && double.parse(_input) > 0) {
      if (double.parse(_input) > confirmedBalance / 1e8) {
        _errorIndex = 0;
        _isNextButtonEnabled = false;
      } else if (double.parse(_input) <= dustLimit / 1e8) {
        _errorIndex = 1;
        _isNextButtonEnabled = false;
      } else {
        _errorIndex = null;
        _isNextButtonEnabled = true;
      }
    } else {
      _errorIndex = null;
      _isNextButtonEnabled = false;
    }

    notifyListeners();
  }

  void setAmountWithInput() {
    _sendInfoProvider.setAmount(double.parse(_input));
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
  }

  void setMaxAmount() {
    _input = UnitUtil.satoshiToBitcoin(_confirmedBalance).toStringAsFixed(8);

    if (double.parse(_input) <= dustLimit / 1e8) {
      _errorIndex = 1;
      _isNextButtonEnabled = false;
      return;
    }

    _errorIndex = null;
    _isNextButtonEnabled = true;

    notifyListeners();
  }
}
