import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';

class UtxoListViewModel extends ChangeNotifier {
  final int _walletId;
  final WalletProvider _walletProvider;
  final UtxoTagProvider _tagProvider;
  final ConnectivityProvider _connectProvider;
  final UpbitConnectModel _upbitConnectModel;

  WalletListItemBase? _walletListBaseItem;
  WalletInitState _prevWalletInitState = WalletInitState.never;
  WalletType _walletType = WalletType.singleSignature;

  String _walletName = '';
  String _selectedUtxoTagName = t.all;
  bool _isUtxoListLoadComplete = false;
  List<UtxoState> _utxoList = [];
  UtxoOrderEnum _selectedUtxoOrder = UtxoOrderEnum.byTimestampDesc;

  String get walletName => _walletName;
  String get selectedUtxoTagName => _selectedUtxoTagName;
  int? get bitcoinPriceKrw => _upbitConnectModel.bitcoinPriceKrw;
  bool get isUtxoListLoadComplete => _isUtxoListLoadComplete;
  bool get isUpdatedTagList => _tagProvider.isUpdatedTagList;
  bool get isUtxoTagListEmpty => _tagProvider.tagList.isEmpty;
  bool? get isNetworkOn => _connectProvider.isNetworkOn;
  List<UtxoState> get utxoList => _utxoList;
  List<UtxoTag> get selectedTagList => _tagProvider.selectedTagList;
  List<UtxoTag> get utxoTagList => _tagProvider.tagList;
  WalletType get walletType => _walletType;
  WalletInitState get walletInitState => _walletProvider.walletInitState;
  UtxoOrderEnum get selectedUtxoOrder => _selectedUtxoOrder;

  int get balance =>
      _walletProvider.getWalletBalance(_walletListBaseItem!.id).total;

  UtxoListViewModel(
    this._walletId,
    this._walletProvider,
    this._tagProvider,
    this._connectProvider,
    this._upbitConnectModel,
  ) {
    _prevWalletInitState = _walletProvider.walletInitState;
    final walletBaseItem = _walletProvider.getWalletById(_walletId);
    _walletListBaseItem = walletBaseItem;
    _walletType = walletBaseItem.walletType;

    if (_walletProvider.walletInitState == WalletInitState.finished) {
      getUtxoListWithHoldingAddress();
    }

    _tagProvider.initTagList(_walletId);

    _walletName = walletBaseItem.name.length > 20
        ? '${walletBaseItem.name.substring(0, 17)}...'
        : walletBaseItem.name;
  }

  void setSelectedUtxoTagName(String value) {
    _selectedUtxoTagName = value;
    notifyListeners();
  }

  void getUtxoListWithHoldingAddress() {
    if (_walletListBaseItem == null) return;

    _utxoList = _walletListBaseItem!.utxoList;

    if (_utxoList.isNotEmpty) {
      for (var utxo in _utxoList) {
        final tags =
            _tagProvider.loadSelectedUtxoTagList(_walletId, utxo.utxoId);

        utxo.tags = tags;

        debugPrint('tags $tags');
      }
    }
    _isUtxoListLoadComplete = true;
    UtxoState.sortUtxo(_utxoList, _selectedUtxoOrder);
    notifyListeners();
  }

  void updateProvider() async {
    if (_prevWalletInitState != WalletInitState.finished &&
        _walletProvider.walletInitState == WalletInitState.finished) {
      getUtxoListWithHoldingAddress();
    }
    _prevWalletInitState = _walletProvider.walletInitState;

    notifyListeners();
  }

  void updateUtxoFilter(UtxoOrderEnum selectedUtxoFilter) async {
    _selectedUtxoOrder = selectedUtxoFilter;
    UtxoState.sortUtxo(_utxoList, selectedUtxoFilter);
    notifyListeners();
  }

  void updateUtxoTagList(String utxoId, List<UtxoTag> utxoTagList) {
    final findUtxo = utxoList.firstWhere((item) => item.utxoId == utxoId);
    findUtxo.tags?.clear();
    findUtxo.tags?.addAll(utxoTagList);
    debugPrint('findUtxo.tags: ${findUtxo.tags}');
    notifyListeners();
  }

  void refreshWalletProvider(int id) {
    _walletProvider.initWallet(targetId: id);
  }
}
