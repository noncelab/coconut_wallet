import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';

class AddressListViewModel extends ChangeNotifier {
  /// Common variables ---------------------------------------------------------
  final WalletProvider _walletProvider;

  /// Wallet variables ---------------------------------------------------------
  List<Address> _receivingAddressList = [];
  List<Address> _changeAddressList = [];
  WalletBase? _walletBase;
  WalletListItemBase? _walletBaseItem;

  AddressListViewModel(this._walletProvider, int id, int firstCount) {
    _initialize(id, firstCount);
  }
  List<Address>? get changeAddressList => _changeAddressList;
  List<Address>? get receivingAddressList => _receivingAddressList;
  WalletBase? get walletBase => _walletBase;

  WalletListItemBase? get walletBaseItem => _walletBaseItem;

  /// 초기화
  void _initialize(int id, int firstCount) {
    _walletBaseItem = _walletProvider.getWalletById(id);
    _walletBase = _walletBaseItem!.walletBase;
    _receivingAddressList = _walletBase!.getAddressList(0, firstCount, false);
    _changeAddressList = _walletBase!.getAddressList(0, firstCount, true);
    notifyListeners();
  }
}
