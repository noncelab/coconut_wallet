import 'dart:collection';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/extensions/double_extensions.dart';
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
  int? _totalUsedAmount;
  Psbt? _unsignedPsbt;

  late double _amount;
  late List<String> _addresses;
  Map<String, double>? _recipientsForBatch;

  SendConfirmViewModel(this._sendInfoProvider, this._walletProvider) {
    _walletListItemBase = _walletProvider.getWalletById(_sendInfoProvider.walletId!);
    if (_sendInfoProvider.recipientsForBatch != null) {
      _setBatchTxParams();
    } else {
      _setSingleTxParams();
    }
  }

  double get amount => _amount;
  List<String> get addresses => _addresses;
  Map<String, double>? get recipientsForBatch =>
      _recipientsForBatch == null ? null : UnmodifiableMapView(_recipientsForBatch!);

  int? get estimatedFee => _unsignedPsbt?.fee;
  String get walletName => _walletListItemBase.name;
  int? get totalUsedAmount => _totalUsedAmount;

  void _setSingleTxParams() {
    _amount = _sendInfoProvider.amount!;
    _addresses = [_sendInfoProvider.recipientAddress!];
  }

  void _setBatchTxParams() {
    _recipientsForBatch = _sendInfoProvider.recipientsForBatch!;
    double totalSendAmount = 0;
    List<String> addresses = [];
    _recipientsForBatch!.forEach((key, value) {
      totalSendAmount += value;
      addresses.add('$key ($value ${t.btc})');
    });
    _amount = totalSendAmount.truncateTo8();
    _addresses = addresses;
  }

  Future<void> setEstimatedFeeAndTotalUsedAmount() async {
    _unsignedPsbt = await _generateUnsignedPsbt();
    _totalUsedAmount = UnitUtil.convertBitcoinToSatoshi(_amount) + _unsignedPsbt!.fee;
    notifyListeners();
  }

  Future<Psbt> _generateUnsignedPsbt() async {
    assert(_sendInfoProvider.transaction != null);
    return Psbt.fromTransaction(_sendInfoProvider.transaction!, _walletListItemBase.walletBase);
  }

  void setTxWaitingForSign() {
    assert(_unsignedPsbt != null);
    _sendInfoProvider.setTxWaitingForSign(_unsignedPsbt!.serialize());
  }
}
