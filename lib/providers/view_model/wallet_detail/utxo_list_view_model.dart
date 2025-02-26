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
  late final int _walletId;
  late final WalletProvider _walletProvider;
  late final UtxoTagProvider _tagProvider;
  late final ConnectivityProvider _connectProvider;
  late final UpbitConnectModel _upbitConnectModel;
  late final WalletListItemBase _walletListBaseItem;

  WalletInitState _prevWalletInitState = WalletInitState.never;

  String _selectedUtxoTagName = t.all;
  List<UtxoState> _utxoList = [];
  UtxoOrderEnum _selectedUtxoOrder = UtxoOrderEnum.byTimestampDesc;

  bool _isUtxoListLoadComplete = false;

  String get selectedUtxoTagName => _selectedUtxoTagName;
  int? get bitcoinPriceKrw => _upbitConnectModel.bitcoinPriceKrw;
  bool get isUtxoListLoadComplete => _isUtxoListLoadComplete;
  bool get isUpdatedTagList => _tagProvider.isUpdatedTagList;
  bool get isUtxoTagListEmpty => _tagProvider.utxoTags.isEmpty;
  bool? get isNetworkOn => _connectProvider.isNetworkOn;
  List<UtxoState> get utxoList => _utxoList;
  List<UtxoTag> get selectedTagList => _tagProvider.utxoTagsForSelectedUtxo;

  List<UtxoTag> _utxoTags = [];
  List<UtxoTag> get utxoTagList => _utxoTags;
  // List<UtxoTag> get utxoTagList => _tagProvider.utxoTags;
  WalletType get walletType => _walletListBaseItem.walletType;
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
    _walletListBaseItem = _walletProvider.getWalletById(_walletId);
    _prevWalletInitState = _walletProvider.walletInitState;

    if (_walletProvider.walletInitState == WalletInitState.finished) {
      _getUtxoListWithHoldingAddress();
    }

    _utxoTags = _tagProvider.fetchUtxoTagsByWalletId(_walletId);
    Logger.log(_tagProvider.utxoTags.length);
  }

  void setSelectedUtxoTagName(String value) {
    _selectedUtxoTagName = value;
    notifyListeners();
  }

  Future<void> _getUtxoListWithHoldingAddress() async {
    // 더이상 _walletListBaseItem.utxoList를 사용하지 않음.
    // wallet provider를 통해 utxo List를 가져오도록 수정
    // _utxoList = _walletListBaseItem.utxoList;
    _utxoList = _walletProvider.getWalletUtxoList(_walletId);
    debugPrint('_utxoList ${_utxoList.length}');

    if (_utxoList.isNotEmpty) {
      for (var utxo in _utxoList) {
        final tags = _tagProvider.fetchUtxoTagsByUtxoId(_walletId, utxo.utxoId);

        utxo.tags = tags;

        debugPrint('tags $tags');
      }
    } else {
      debugPrint('utxoList is empty');
    }
    _isUtxoListLoadComplete = true;
    UtxoState.sortUtxo(_utxoList, _selectedUtxoOrder);
    notifyListeners();
  }

  void updateProvider() async {
    if (_prevWalletInitState != WalletInitState.finished &&
        _walletProvider.walletInitState == WalletInitState.finished) {
      _getUtxoListWithHoldingAddress();
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
