import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';

class SendConfirmViewModel extends ChangeNotifier {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;
  late WalletListItemBase _walletListItemBase;
  late int? _bitcoinPriceKrw;

  SendConfirmViewModel(
      this._sendInfoProvider, this._walletProvider, this._bitcoinPriceKrw) {
    _walletListItemBase =
        _walletProvider.getWalletById(_sendInfoProvider.walletId!);
  }

  String get address => _sendInfoProvider.recipientAddress!;
  double get amount => _sendInfoProvider.amount!;
  int? get bitcoinPriceKrw => _bitcoinPriceKrw;
  int? get estimatedFee => _sendInfoProvider.estimatedFee;
  String get walletName => _walletListItemBase.name;

  Future<String> generateUnsignedPsbt() async {
    // utxo selection
    if (_sendInfoProvider.transaction != null) {
      var psbt = PSBT.fromTransaction(
          _sendInfoProvider.transaction!, _walletListItemBase.walletBase);
      return psbt.serialize();
    }

    String generatedTx;
    if (_sendInfoProvider.isMaxMode!) {
      generatedTx = await _walletListItemBase.walletFeature
          .generatePsbtWithMaximum(
              _sendInfoProvider.recipientAddress!, _sendInfoProvider.feeRate!);
    } else {
      generatedTx = await _walletListItemBase.walletFeature.generatePsbt(
          _sendInfoProvider.recipientAddress!,
          UnitUtil.bitcoinToSatoshi(_sendInfoProvider.amount!),
          _sendInfoProvider.feeRate!);
    }

    // printLongString(">>>>>> psbt 생성");
    // printLongString(generatedTx);
    return generatedTx;
  }

  setTxWaitingForSign(String transaction) {
    _sendInfoProvider.setTxWaitingForSign(transaction);
  }

  updateBitcoinPriceKrw(int btcPriceInKrw) {
    _bitcoinPriceKrw = btcPriceInKrw;
    notifyListeners();
  }
}
