import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SendAddressViewModel extends ChangeNotifier {
  final invalidAddressMessage = t.errors.address_error.invalid;
  final noTestnetAddressMessage = t.errors.address_error.not_for_testnet;
  final noMainnetAddressMessage = t.errors.address_error.not_for_mainnet;
  final noRegtestnetAddressMessage = t.errors.address_error.not_for_regtest;

  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;
  late bool? _isNetworkOn;
  String? _address;
  SendAddressViewModel(this._sendInfoProvider, this._isNetworkOn, this._walletProvider);

  String? get address => _address;

  bool get isNetworkOn => _isNetworkOn == true;

  void clearSendInfoProvider() {
    _sendInfoProvider.clear();
  }

  void loadDataFromClipboard() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final clipboardText = data?.text ?? '';
    if (clipboardText.isNotEmpty) {
      try {
        await validateAddress(clipboardText);
        _address = _isBech32(clipboardText) ? clipboardText.toLowerCase() : clipboardText;
      } catch (_) {
        _address = null;
      }
      notifyListeners();
    }
  }

  void saveWalletIdAndRecipientAddress(int id, String address) {
    _sendInfoProvider.setWalletId(id);
    _sendInfoProvider.setRecipientAddress(_isBech32(address) ? address.toLowerCase() : address);
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
  }

  Future<void> validateAddress(String recipient) async {
    if (recipient.isEmpty) {
      throw invalidAddressMessage;
    }

    final normalized = recipient.toLowerCase();

    // Bech32m(T2R) 주소 최대 62자
    if (normalized.length < 26 || normalized.length > 62) {
      throw invalidAddressMessage;
    }

    if (NetworkType.currentNetworkType == NetworkType.testnet) {
      if (normalized.startsWith('1') ||
          normalized.startsWith('3') ||
          normalized.startsWith('bc1')) {
        throw noTestnetAddressMessage;
      }
    } else if (NetworkType.currentNetworkType == NetworkType.mainnet) {
      if (normalized.startsWith('m') ||
          normalized.startsWith('n') ||
          normalized.startsWith('2') ||
          normalized.startsWith('tb1')) {
        throw noMainnetAddressMessage;
      }
    } else if (NetworkType.currentNetworkType == NetworkType.regtest) {
      if (!normalized.startsWith('bcrt1')) {
        throw noRegtestnetAddressMessage;
      }
    }

    bool result = false;
    try {
      final addressForValidation = _isBech32(normalized) ? normalized : recipient;
      result = WalletUtility.validateAddress(addressForValidation);
    } catch (e) {
      throw invalidAddressMessage;
    }

    if (!result) {
      throw invalidAddressMessage;
    }
  }

  bool _isBech32(String address) {
    final normalizedAddress = address.toLowerCase();
    return normalizedAddress.startsWith('bc1') ||
        normalizedAddress.startsWith('tb1') ||
        normalizedAddress.startsWith('bcrt1');
  }

  /// --- batch transaction
  bool isSendAmountValid(int walletId, int totalSendAmount) {
    return _walletProvider.getWalletBalance(walletId).confirmed > totalSendAmount;
  }

  void saveWalletIdAndBatchRecipients(int id, Map<String, double> recipients) {
    _sendInfoProvider.setWalletId(id);

    final normalizedRecipients = <String, double>{};
    for (final entry in recipients.entries) {
      final address = _isBech32(entry.key) ? entry.key.toLowerCase() : entry.key;
      normalizedRecipients[address] = entry.value;
    }
    _sendInfoProvider.setRecipientsForBatch(normalizedRecipients);
  }
}
