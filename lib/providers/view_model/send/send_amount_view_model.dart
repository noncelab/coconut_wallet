import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/material.dart';

class SendAmountViewModel extends ChangeNotifier {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;
  late bool? _isNetworkOn;
  late int _confirmedBalance;
  late int _incomingBalance;
  late String _input;
  late bool _isNextButtonEnabled;
  int? _errorIndex;
  bool _isUtxoUpdating = false;
  Unit _currentUnit = Unit.btc;

  SendAmountViewModel(this._sendInfoProvider, this._walletProvider, this._isNetworkOn) {
    _initBalances(); // _confirmedBalance, _incomingBalance
    _input = '';
    _isNextButtonEnabled = false;

    _addWalletUpdateListner();
  }

  int get confirmedBalance => _confirmedBalance;

  int? get errorIndex => _errorIndex;

  String get input => _input;

  bool get isNetworkOn => _isNetworkOn == true;

  bool get isNextButtonEnabled => _isNextButtonEnabled;

  int get incomingBalance => _incomingBalance;

  Unit get currentUnit => _currentUnit;

  bool get isBtcUnit => _currentUnit == Unit.btc;

  bool get isSatsUnit => !isBtcUnit;

  num get dustLimitDenominator => (isBtcUnit ? 1e8 : 1);

  void toggleUnit() {
    _currentUnit = isBtcUnit ? Unit.sats : Unit.btc;
    if (_input.isNotEmpty && _input != '0') {
      _input = (isBtcUnit
              ? UnitUtil.satoshiToBitcoin(int.parse(_input))
              : UnitUtil.bitcoinToSatoshi(double.parse(_input)))
          .toString();
    }

    notifyListeners();
  }

  void onBeforeGoNextScreen() {
    _setAmountWithInput();
    _removeWalletUpdateListener();
  }

  void onBackFromNextScreen() {
    _addWalletUpdateListner();
  }

  void onKeyTap(String newInput) {
    if (newInput == ' ') return;
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
      if (double.parse(_input) > confirmedBalance / dustLimitDenominator) {
        _errorIndex = 0;
        _isNextButtonEnabled = false;
      } else if (double.parse(_input) <= dustLimit / dustLimitDenominator) {
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

  void _setAmountWithInput() {
    double bitcoin =
        isBtcUnit ? double.parse(_input) : UnitUtil.satoshiToBitcoin(int.parse(_input));
    _sendInfoProvider.setAmount(bitcoin);
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  void setMaxAmount() {
    _input =
        (isBtcUnit ? UnitUtil.satoshiToBitcoin(_confirmedBalance) : _confirmedBalance).toString();
    if (double.parse(_input) <= dustLimit / dustLimitDenominator) {
      _errorIndex = 1;
      _isNextButtonEnabled = false;
      return;
    }

    _errorIndex = null;
    _isNextButtonEnabled = true;

    notifyListeners();
  }

  void _initBalances() {
    List<UtxoState> utxos = _walletProvider.getUtxoList(_sendInfoProvider.walletId!);

    int unspentBalance = 0, incomingBalance = 0;
    for (UtxoState utxo in utxos) {
      if (utxo.status == UtxoStatus.unspent) {
        unspentBalance += utxo.amount;
      } else if (utxo.status == UtxoStatus.incoming) {
        incomingBalance += utxo.amount;
      }
    }

    _confirmedBalance = unspentBalance;
    _incomingBalance = incomingBalance;
  }

  void _onWalletUpdated(WalletUpdateInfo walletUpdateInfo) {
    if (walletUpdateInfo.utxo == UpdateStatus.syncing) {
      _isUtxoUpdating = true;
    } else if (walletUpdateInfo.utxo == UpdateStatus.completed && _isUtxoUpdating) {
      _isUtxoUpdating = false;
      _initBalances();
      notifyListeners();
    }
  }

  // pending tx가 완료되었을 때 잔액을 업데이트 하기 위해
  void _addWalletUpdateListner() {
    _walletProvider.addWalletUpdateListener(_sendInfoProvider.walletId!, _onWalletUpdated);
  }

  void _removeWalletUpdateListener() {
    _walletProvider.removeWalletUpdateListener(_sendInfoProvider.walletId!, _onWalletUpdated);
  }

  @override
  void dispose() {
    if (_sendInfoProvider.walletId != null) {
      _removeWalletUpdateListener();
    }
    super.dispose();
  }
}
