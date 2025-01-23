import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:flutter/material.dart';

class SendAddressViewModel extends ChangeNotifier {
  late final SendInfoProvider _sendInfoProvider;
  late bool? _isNetworkOn;

  SendAddressViewModel(this._sendInfoProvider, this._isNetworkOn);

  bool get isNetworkOn => _isNetworkOn == true;

  saveWalletIdAndReceipientAddress(int id, String address) {
    _sendInfoProvider.setWalletId(id);
    _sendInfoProvider.setReceipientAddress(address);
  }

  setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
  }

  clearSendInfoProvider() {
    _sendInfoProvider.clear();
  }
}
