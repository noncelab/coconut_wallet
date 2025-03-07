import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/material.dart';

class SendFeeSelectionViewModel extends ChangeNotifier {
  final SendInfoProvider _sendInfoProvider;
  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;

  late final WalletListItemBase _walletListItemBase;
  late int _confirmedBalance;
  late int _unconfirmedBalance;
  late int? _bitcoinPriceKrw;
  late bool _isMultisigWallet;
  late bool _isMaxMode;
  late int _walletId;
  late double _amount;
  late String _recipientAddress;
  late bool? _isNetworkOn;

  SendFeeSelectionViewModel(this._sendInfoProvider, this._walletProvider,
      this._nodeProvider, this._bitcoinPriceKrw, this._isNetworkOn) {
    var balance = _walletProvider.getWalletBalance(_sendInfoProvider.walletId!);
    _walletListItemBase =
        _walletProvider.getWalletById(_sendInfoProvider.walletId!);
    _confirmedBalance = balance.confirmed;
    _unconfirmedBalance = balance.unconfirmed;
    _isMultisigWallet =
        _walletListItemBase.walletType == WalletType.multiSignature;
    _bitcoinPriceKrw = _bitcoinPriceKrw;
    _walletId = _sendInfoProvider.walletId!;
    _amount = _sendInfoProvider.amount!;
    _isMaxMode = _confirmedBalance == UnitUtil.bitcoinToSatoshi(_amount);
    _recipientAddress = _sendInfoProvider.recipientAddress!;
    _isNetworkOn = isNetworkOn;

    _updateSendInfoProvider();
  }

  double get amount => _amount;
  int? get bitcoinPriceKrw => _bitcoinPriceKrw;
  int get confirmedBalance => _confirmedBalance;
  bool get isMaxMode => _isMaxMode;
  bool get isMultisigWallet => _isMultisigWallet;
  bool get isNetworkOn => _isNetworkOn == true;
  String get recipientAddress => _recipientAddress;
  int get unconfirmedBalance => _unconfirmedBalance;
  int get walletId => _walletId;
  WalletProvider get walletProvider => _walletProvider;
  NodeProvider get nodeprovider => _nodeProvider;
  int estimateFee(int satsPerVb) {
    final utxoPool = _walletProvider.getUtxoList(walletId);
    final wallet = _walletProvider.getWalletById(walletId);
    final changeAddress = _walletProvider.getChangeAddress(walletId);
    final amount = UnitUtil.bitcoinToSatoshi(_amount);

    // FIXME
    // forSinglePayment: utxoList 중 필요한 utxo만 선택하는 로직 추가

    final transaction = _isMaxMode
        ? Transaction.forSweep(
            utxoPool, _recipientAddress, satsPerVb, wallet.walletBase)
        : Transaction.forSinglePayment(utxoPool, _recipientAddress,
            changeAddress.address, amount, satsPerVb, wallet.walletBase);

    if (_isMultisigWallet) {
      final multisigWallet = wallet.walletBase as MultisignatureWallet;
      return transaction.estimateFee(satsPerVb, wallet.walletBase.addressType,
          requiredSignature: multisigWallet.requiredSignature,
          totalSigner: multisigWallet.totalSigner);
    }

    return transaction.estimateFee(satsPerVb, wallet.walletBase.addressType);
  }

  double getAmount(int estimatedFee) {
    return _isMaxMode
        ? UnitUtil.satoshiToBitcoin(_confirmedBalance - estimatedFee)
        : amount;
  }

  bool isBalanceEnough(int? estimatedFee) {
    if (estimatedFee == null || estimatedFee == 0) return false;
    if (_isMaxMode) return (confirmedBalance - estimatedFee) > dustLimit;

    return (UnitUtil.bitcoinToSatoshi(amount) + estimatedFee) <=
        confirmedBalance;
  }

  setAmount(double amount) {
    _sendInfoProvider.setAmount(amount);
  }

  void setBitcoinPriceKrw(int price) {
    _bitcoinPriceKrw = price;
    notifyListeners();
  }

  setEstimatedFee(int estimatedFee) {
    _sendInfoProvider.setEstimatedFee(estimatedFee);
  }

  setFeeRate(int feeRate) {
    _sendInfoProvider.setFeeRate(feeRate);
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  void _updateSendInfoProvider() {
    _sendInfoProvider.setIsMultisig(_isMultisigWallet);
    _sendInfoProvider.setIsMaxMode(_isMaxMode);
  }
}
