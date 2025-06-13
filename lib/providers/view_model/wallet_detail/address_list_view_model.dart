import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/address.dart';
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

  AddressListViewModel(this._walletProvider, int id) {
    _walletBaseItem = _walletProvider.getWalletById(id);
    _walletBase = _walletBaseItem!.walletBase;
  }

  List<WalletAddress> get changeAddressList => _changeAddressList;
  List<WalletAddress> get receivingAddressList => _receivingAddressList;
  WalletBase? get walletBase => _walletBase;
  WalletListItemBase? get walletBaseItem => _walletBaseItem;
  WalletProvider get walletProvider => _walletProvider;

  int _receivingCursor = kInitialAddressCount;
  int _changeCursor = kInitialAddressCount;

  int get receivingInitialCursor => _receivingCursor;
  int get changeInitialCursor => _changeCursor;

  /// AddressList 초기화 함수(showOnlyUnusedAddresses 변경시 호출)
  Future<void> initializeAddressList(int firstCount, bool showOnlyUnusedAddresses) async {
    Logger.log(
        "[address_list_view_model.initializeAddressList] firstCount = $firstCount, showOnlyUnusedAddresses = $showOnlyUnusedAddresses");
    _receivingAddressList = await getWalletAddressList(
      _walletBaseItem!,
      0,
      firstCount,
      false,
      showOnlyUnusedAddresses,
    );
    _changeAddressList = await getWalletAddressList(
      _walletBaseItem!,
      0,
      firstCount,
      true,
      showOnlyUnusedAddresses,
    );
    notifyListeners();
  }

  Future<List<WalletAddress>> getWalletAddressList(
    WalletListItemBase walletItem,
    int cursor,
    int count,
    bool isChange,
    bool showOnlyUnusedAddresses,
  ) async {
    final list = await _walletProvider.getWalletAddressList(
      walletItem,
      cursor,
      count,
      isChange,
      showOnlyUnusedAddresses,
    );

    if (isChange) {
      _changeCursor = list.last.index;
    } else {
      _receivingCursor = list.last.index;
    }

    return list;
  }
}
