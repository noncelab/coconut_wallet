import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';

class BroadcastingViewModel extends ChangeNotifier {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;
  late final WalletBase _walletBase;
  late final int _walletId;
  late bool? _isNetworkOn;

  BroadcastingViewModel(
      this._sendInfoProvider, this._walletProvider, this._isNetworkOn) {
    _walletBase =
        _walletProvider.getWalletById(_sendInfoProvider.walletId!).walletBase;
    _walletId = _sendInfoProvider.walletId!;
  }

  bool get isMultisig => _sendInfoProvider.isMultisig!;
  String get txWaitingForSign => _sendInfoProvider.txWaitingForSign!;
  AddressType get walletAddressType => _walletBase.addressType;
  String get signedTransaction => _sendInfoProvider.signedPsbt!;
  int get walletId => _walletId;
  bool get isNetworkOn => _isNetworkOn == true;

  WalletBase getWalletBase() {
    return _walletProvider
        .getWalletById(_sendInfoProvider.walletId!)
        .walletBase;
  }

  void setSignedPsbtBase64(String signedPsbtBase64) {
    _sendInfoProvider.setSignedPsbtBase64Encoded(signedPsbtBase64);
  }

  Future<Result<String, CoconutError>> broadcast(Transaction signedTx) async {
    return await _walletProvider.broadcast(signedTx);
  }

  void clearSendInfo() {
    _sendInfoProvider.clear();
  }

  setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
  }
}
