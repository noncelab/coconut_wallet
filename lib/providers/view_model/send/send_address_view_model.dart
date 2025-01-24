import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SendAddressViewModel extends ChangeNotifier {
  final invalidAddressMessage = '올바른 주소가 아니에요.';
  final noTestnetAddressMessage = '테스트넷 주소가 아니에요.';
  final noMainnetAddressMessage = '메인넷 주소가 아니에요.';
  final noRegtestnetAddressMessage = '레그테스트넷 주소가 아니에요.';

  late final SendInfoProvider _sendInfoProvider;
  late bool? _isNetworkOn;
  String? _address;
  SendAddressViewModel(this._sendInfoProvider, this._isNetworkOn);

  String? get address => _address;

  bool get isNetworkOn => _isNetworkOn == true;

  clearSendInfoProvider() {
    _sendInfoProvider.clear();
  }

  void loadDataFromClipboardIfValid() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final clipboardText = data?.text ?? '';
    if (clipboardText.isNotEmpty) {
      try {
        await validateAddress(clipboardText);
        _address = clipboardText;
        notifyListeners();
      } catch (_) {
        // ignore
      }
    }
  }

  saveWalletIdAndReceipientAddress(int id, String address) {
    _sendInfoProvider.setWalletId(id);
    _sendInfoProvider.setReceipientAddress(address);
  }

  setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
  }

  Future validateAddress(String recipient) async {
    if (recipient.isEmpty || recipient.length < 26) {
      throw invalidAddressMessage;
    }

    if (BitcoinNetwork.currentNetwork == BitcoinNetwork.testnet) {
      if (recipient.startsWith('1') ||
          recipient.startsWith('3') ||
          recipient.startsWith('bc1')) {
        throw noTestnetAddressMessage;
      }
    } else if (BitcoinNetwork.currentNetwork == BitcoinNetwork.mainnet) {
      if (recipient.startsWith('m') ||
          recipient.startsWith('n') ||
          recipient.startsWith('2') ||
          recipient.startsWith('tb1')) {
        throw noMainnetAddressMessage;
      }
    } else if (BitcoinNetwork.currentNetwork == BitcoinNetwork.regtest) {
      if (!recipient.startsWith('bcrt1')) {
        throw noRegtestnetAddressMessage;
      }
    }

    bool result = false;
    try {
      result = WalletUtility.validateAddress(recipient);
    } catch (e) {
      throw invalidAddressMessage;
    }

    if (!result) {
      throw invalidAddressMessage;
    }
  }
}
