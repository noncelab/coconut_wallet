import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

class AddressListViewModel extends ChangeNotifier {
  /// Common variables ---------------------------------------------------------
  final WalletProvider _walletProvider;

  /// Wallet variables ---------------------------------------------------------
  List<WalletAddress> _receivingAddressList = [];
  List<WalletAddress> _changeAddressList = [];
  WalletBase? _walletBase;
  WalletListItemBase? _walletBaseItem;
  final void Function(bool, int) _onCursorUpdate;

  AddressListViewModel(this._walletProvider, this._onCursorUpdate, int id) {
    _walletBaseItem = _walletProvider.getWalletById(id);
    _walletBase = _walletBaseItem!.walletBase;
  }

  List<WalletAddress> get changeAddressList => _changeAddressList;
  List<WalletAddress> get receivingAddressList => _receivingAddressList;
  WalletBase? get walletBase => _walletBase;
  WalletListItemBase? get walletBaseItem => _walletBaseItem;
  WalletProvider get walletProvider => _walletProvider;

  /// AddressList 초기화 함수(showOnlyUnusedAddresses 변경시 호출)
  Future<void> initializeAddressList(int firstCount, bool showOnlyUnusedAddresses) async {
    Logger.log(
        "[address_list_view_model.initializeAddressList] firstCount = $firstCount, showOnlyUnusedAddresses = $showOnlyUnusedAddresses");
    _receivingAddressList = await _walletProvider.getWalletAddressList(
        _walletBaseItem!, 0, firstCount, false, showOnlyUnusedAddresses, _onCursorUpdate);
    _changeAddressList = await _walletProvider.getWalletAddressList(
        _walletBaseItem!, 0, firstCount, true, showOnlyUnusedAddresses, _onCursorUpdate);
    notifyListeners();
  }
}
