import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';

class AddressSearchViewModel extends ChangeNotifier {
  final invalidAddressMessage = t.errors.address_error.invalid;
  final noTestnetAddressMessage = t.errors.address_error.not_for_testnet;
  final noMainnetAddressMessage = t.errors.address_error.not_for_mainnet;
  final noRegtestnetAddressMessage = t.errors.address_error.not_for_regtest;

  /// Common variables ---------------------------------------------------------
  final WalletProvider _walletProvider;
  final PreferenceProvider _preferenceProvider;

  /// Wallet variables ---------------------------------------------------------
  List<WalletAddress> _receivingAddressList = [];
  List<WalletAddress> _changeAddressList = [];
  WalletBase? _walletBase;
  WalletListItemBase? _walletBaseItem;
  int _generatedReceiveIndex = 0;
  int _generatedChangeIndex = 0;

  AddressSearchViewModel(this._walletProvider, this._preferenceProvider, int id) {
    _initialize(id);
  }

  List<WalletAddress> get changeAddressList {
    if (_preferenceProvider.showOnlyUnusedAddresses) {
      return _changeAddressList.where((address) => !address.isUsed).toList();
    }
    return _changeAddressList;
  }

  List<WalletAddress> get receivingAddressList {
    if (_preferenceProvider.showOnlyUnusedAddresses) {
      return _receivingAddressList.where((address) => !address.isUsed).toList();
    }
    return _receivingAddressList;
  }

  int get searchedAddressLength => changeAddressList.length + receivingAddressList.length;

  WalletBase? get walletBase => _walletBase;

  WalletListItemBase? get walletBaseItem => _walletBaseItem;
  WalletProvider get walletProvider => _walletProvider;
  int get generatedReceiveIndex => _generatedReceiveIndex;
  int get generatedChangeIndex => _generatedChangeIndex;

  void _initialize(int id) {
    _walletBaseItem = _walletProvider.getWalletById(id);
    _walletBase = _walletBaseItem!.walletBase;

    final (receiveIndex, changeIndex) = _walletProvider.getGeneratedIndexes(_walletBaseItem!);
    _generatedReceiveIndex = receiveIndex;
    _generatedChangeIndex = changeIndex;
    notifyListeners();
  }

  void searchWalletAddressList(String keyword) {
    final addressList = _walletProvider.searchWalletAddressList(_walletBaseItem!, keyword);
    _changeAddressList = addressList.where((address) => address.isChange).toList();
    _receivingAddressList = addressList.where((address) => !address.isChange).toList();
    notifyListeners();
  }

  Future<void> validateAddress(String recipient) async {
    if (recipient.isEmpty || recipient.length < 26) {
      throw invalidAddressMessage;
    }

    if (NetworkType.currentNetworkType == NetworkType.testnet) {
      if (recipient.startsWith('1') || recipient.startsWith('3') || recipient.startsWith('bc1')) {
        throw noTestnetAddressMessage;
      }
    } else if (NetworkType.currentNetworkType == NetworkType.mainnet) {
      if (recipient.startsWith('m') ||
          recipient.startsWith('n') ||
          recipient.startsWith('2') ||
          recipient.startsWith('tb1')) {
        throw noMainnetAddressMessage;
      }
    } else if (NetworkType.currentNetworkType == NetworkType.regtest) {
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
