import 'dart:collection';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/material.dart';

class SendConfirmViewModel extends ChangeNotifier {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;
  late WalletListItemBase _walletListItemBase;
  late int _estimatedFee;
  late int _totalUsedAmount;

  late double _amount;
  late List<String> _addresses;
  Map<String, double>? _recipientsForBatch;

  SendConfirmViewModel(this._sendInfoProvider, this._walletProvider) {
    _walletListItemBase =
        _walletProvider.getWalletById(_sendInfoProvider.walletId!);
    _estimatedFee = _sendInfoProvider.estimatedFee!;
    if (_sendInfoProvider.recipientsForBatch != null) {
      _setBatchTxParams();
    } else {
      _setSingleTxParams();
    }
  }

  double get amount => _amount;
  List<String> get addresses => _addresses;
  Map<String, double>? get recipientsForBatch => _recipientsForBatch == null
      ? null
      : UnmodifiableMapView(_recipientsForBatch!);

  int get estimatedFee => _estimatedFee;
  String get walletName => _walletListItemBase.name;
  int get totalUsedAmount => _totalUsedAmount;

  void _setSingleTxParams() {
    _amount = _sendInfoProvider.amount!;
    _addresses = [_sendInfoProvider.recipientAddress!];
    _totalUsedAmount = UnitUtil.bitcoinToSatoshi(_amount) + _estimatedFee;
  }

  void _setBatchTxParams() {
    _recipientsForBatch = _sendInfoProvider.recipientsForBatch!;
    double totalSendAmount = 0;
    List<String> addresses = [];
    _recipientsForBatch!.forEach((key, value) {
      totalSendAmount += value;
      addresses.add('$key ($value ${t.btc})');
    });
    _amount = totalSendAmount;
    _addresses = addresses;
    _totalUsedAmount = UnitUtil.bitcoinToSatoshi(_amount) + _estimatedFee;
  }

  Future<String> generateUnsignedPsbt() async {
    assert(_sendInfoProvider.transaction != null);
    var psbt = Psbt.fromTransaction(
        _sendInfoProvider.transaction!, _walletListItemBase.walletBase);
    return psbt.serialize();
  }

  void setTxWaitingForSign(String transaction) {
    _sendInfoProvider.setTxWaitingForSign(transaction);
  }
}
