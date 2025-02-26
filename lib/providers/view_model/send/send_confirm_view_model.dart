import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/material.dart';

class SendConfirmViewModel extends ChangeNotifier {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;
  late WalletListItemBase _walletListItemBase;
  late int? _bitcoinPriceKrw;
  late double _amount;
  late String _address;

  SendConfirmViewModel(
      this._sendInfoProvider, this._walletProvider, this._bitcoinPriceKrw) {
    _walletListItemBase =
        _walletProvider.getWalletById(_sendInfoProvider.walletId!);
    _amount = _sendInfoProvider.amount!;
    _address = _sendInfoProvider.recipientAddress!;
  }

  double get amount => _amount;
  String get address => _address;
  int? get bitcoinPriceKrw => _bitcoinPriceKrw;
  int? get estimatedFee => _sendInfoProvider.estimatedFee;
  String get walletName => _walletListItemBase.name;

  Future<String> generateUnsignedPsbt() async {
    // utxo selection
    if (_sendInfoProvider.transaction != null) {
      var psbt = Psbt.fromTransaction(
          _sendInfoProvider.transaction!, _walletListItemBase.walletBase);
      return psbt.serialize();
    }

    String generatedTx;
    var utxoList = _walletProvider.getUtxoList(_sendInfoProvider.walletId!);
    if (_sendInfoProvider.isMaxMode!) {
      generatedTx = await _walletListItemBase.walletBase.generatePsbtForSweep(
          utxoList,
          _sendInfoProvider.recipientAddress!,
          _sendInfoProvider.feeRate!);
    } else {
      generatedTx = await _walletListItemBase.walletBase.generatePsbtForPayment(
          utxoList,
          _sendInfoProvider.recipientAddress!,
          _walletProvider.getChangeAddress(_sendInfoProvider.walletId!).address,
          UnitUtil.bitcoinToSatoshi(_sendInfoProvider.amount!),
          _sendInfoProvider.feeRate!);
    }

    // printLongString(">>>>>> psbt 생성");
    // printLongString(generatedTx);
    return generatedTx;
  }

  void setTxWaitingForSign(String transaction) {
    _sendInfoProvider.setTxWaitingForSign(transaction);
  }

  void updateBitcoinPriceKrw(int btcPriceInKrw) {
    _bitcoinPriceKrw = btcPriceInKrw;
    notifyListeners();
  }
}
