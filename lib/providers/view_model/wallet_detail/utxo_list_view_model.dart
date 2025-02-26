import 'dart:math';

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
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

class UtxoListViewModel extends ChangeNotifier {
  late final WalletProvider _walletProvider;
  late final UtxoTagProvider _tagProvider;
  UtxoTagProvider get tagProvider => _tagProvider;
  late final ConnectivityProvider _connectProvider;
  late final UpbitConnectModel _upbitConnectModel;
  late final WalletListItemBase _walletListBaseItem;
  late final int _walletId;

  WalletInitState _prevWalletInitState = WalletInitState.never;

  List<UtxoState> _utxoList = [];
  UtxoOrderEnum _selectedUtxoOrder = UtxoOrderEnum.byTimestampDesc;
  bool _isUtxoListLoadComplete = false;

  String _selectedUtxoTagName = t.all;

  UtxoListViewModel(
    this._walletId,
    this._walletProvider,
    this._tagProvider,
    this._connectProvider,
    this._upbitConnectModel,
  ) {
    _walletListBaseItem = _walletProvider.getWalletById(_walletId);
    _prevWalletInitState = _walletProvider.walletInitState;
    _utxoList = _walletProvider.getUtxoList(_walletId);
    _utxoTagList = _tagProvider.getUtxoTagList(_walletId);

    for (var utxo in _utxoList) {
      final tags = _tagProvider.getUtxoTagsByUtxoId(_walletId, utxo.utxoId);

      utxo.tags = tags;
    }
    _isUtxoListLoadComplete = true;
    UtxoState.sortUtxo(_utxoList, _selectedUtxoOrder);

    // if (_walletProvider.walletInitState == WalletInitState.finished) {
    //   _getUtxoAndTagList();
    // }
  }
  int get balance =>
      _walletProvider.getWalletBalance(_walletListBaseItem.id).total;
  int? get bitcoinPriceKrw => _upbitConnectModel.bitcoinPriceKrw;
  bool? get isNetworkOn => _connectProvider.isNetworkOn;

  bool get isUtxoListLoadComplete => _isUtxoListLoadComplete;

  List<UtxoState> get utxoList => _utxoList;
  UtxoOrderEnum get selectedUtxoOrder => _selectedUtxoOrder;

  bool _isUtxoTagListUpdated = false;
  bool get isUtxoTagListUpdated => _isUtxoTagListUpdated;
  // bool get isUtxoTagListUpdated => _isUtxoTagListUpdated;

  List<UtxoTag> _utxoTagList = [];
  List<UtxoTag> get utxoTagList => _utxoTagList;
  List<UtxoTag> get selectedTagList => _tagProvider.utxoTagsForSelectedUtxo;
  bool get isUtxoTagListEmpty => utxoTagList.isEmpty;

  // 임시
  String get utxoTagListString => _utxoTagList.map((e) => e.name).join(' ');

  String get selectedUtxoTagName => _selectedUtxoTagName;

  WalletInitState get walletInitState => _walletProvider.walletInitState;

  WalletType get walletType => _walletListBaseItem.walletType;

  void refreshWalletProvider(int id) {
    _walletProvider.initWallet(targetId: id);
  }

  void setSelectedUtxoTagName(String value) {
    _selectedUtxoTagName = value;
    notifyListeners();
  }

  void updateProvider() async {
    if (_tagProvider.isUpdatedTagList) {
      _getUtxoAndTagList();
      _tagProvider.resetUtxoTagsUpdateState();
      notifyListeners();
    }
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

  void _getUtxoAndTagList() {
    _isUtxoListLoadComplete = false;
    _utxoList = _walletProvider.getUtxoList(_walletId);
    _utxoTagList = _tagProvider.getUtxoTagList(_walletId);

    final newUtxoTagList = _tagProvider.getUtxoTagList(_walletId);
    _isUtxoTagListUpdated = true;

    // _isUtxoTagListUpdated = !_areListsEqual(_utxoTagList, newUtxoTagList);

    debugPrint(
        '_isUtxoTagListUpdated: $_isUtxoTagListUpdated ${_areListsEqual(_utxoTagList, newUtxoTagList)}');
    _utxoTagList = newUtxoTagList;

    for (var utxo in _utxoList) {
      final tags = _tagProvider.getUtxoTagsByUtxoId(_walletId, utxo.utxoId);

      utxo.tags = tags;
    }
    UtxoState.sortUtxo(_utxoList, _selectedUtxoOrder);
    _isUtxoListLoadComplete = true;

    notifyListeners();
  }

  bool _areListsEqual(List<UtxoTag> list1, List<UtxoTag> list2) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }

    return true;
  }

  void resetUtxoTagsUpdateState() {
    _tagProvider.resetUtxoTagsUpdateState();
  }

  List<String> convertStringToList(String tagString) {
    return List<String>.from(
        tagString.split(' ').where((tag) => tag.isNotEmpty));
  }
}
