import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';

class SendAmountViewModel extends ChangeNotifier {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;
  late bool? _isNetworkOn;
  late int _confirmedBalance;
  late int _unconfirmedBalance;

  SendAmountViewModel(
      this._sendInfoProvider, this._walletProvider, this._isNetworkOn) {
    var wallet = _walletProvider.getWalletById(_sendInfoProvider.walletId!);
    _confirmedBalance = wallet.walletFeature.getBalance();
    _unconfirmedBalance = wallet.walletFeature.getUnconfirmedBalance();
  }

  bool get isNetworkOn => _isNetworkOn == true;
  int get confirmedBalance => _confirmedBalance;
  int get unconfirmedBalance => _unconfirmedBalance;

  setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
  }

  setAmount(String amountInput) {
    _sendInfoProvider.setAmount(double.parse(amountInput));
  }
}
