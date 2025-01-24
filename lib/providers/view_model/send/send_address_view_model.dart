import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SendAddressViewModel extends ChangeNotifier {
  late final SendInfoProvider _sendInfoProvider;
  late bool? _isNetworkOn;
  String? _address;
  SendAddressViewModel(this._sendInfoProvider, this._isNetworkOn);

  String? get address => _address;

  bool get isNetworkOn => _isNetworkOn == true;

  clearSendInfoProvider() {
    _sendInfoProvider.clear();
  }

  void loadData() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final clipboardText = data?.text ?? '';
    if (clipboardText.isNotEmpty &&
        BitcoinNetwork.currentNetwork == BitcoinNetwork.regtest &&
        clipboardText.startsWith('bcrt1') &&
        WalletUtility.validateAddress(clipboardText)) {
      _address = clipboardText;
    } else {
      _address = null;
    }
    notifyListeners();
  }

  saveWalletIdAndRecipientAddress(int id, String address) {
    _sendInfoProvider.setWalletId(id);
    _sendInfoProvider.setRecipientAddress(address);
  }

  setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
  }
}
