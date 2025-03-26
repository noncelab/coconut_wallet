import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

class UtxoListViewModel extends ChangeNotifier {
  late final WalletProvider _walletProvider;
  late final TransactionProvider _txProvider;
  late final UtxoTagProvider _tagProvider;
  late final ConnectivityProvider _connectProvider;
  late final UpbitConnectModel _upbitConnectModel;
  late final WalletListItemBase _walletListBaseItem;
  late final int _walletId;
  // WalletInitState _prevWalletInitState = WalletInitState.never;
  late UpdateStatus _prevUpdateStatus;

  // balance 애니메이션을 위한 이전 잔액을 담는 변수
  late int _prevBalance;

  List<UtxoState> _utxoList = [];
  UtxoOrder _selectedUtxoOrder = UtxoOrder.byTimestampDesc;
  bool _isUtxoListLoadComplete = false;
  String _selectedUtxoTagName = t.all;
  List<UtxoTag> _utxoTagList = [];

  UtxoListViewModel(
    this._walletId,
    this._walletProvider,
    this._txProvider,
    this._tagProvider,
    this._connectProvider,
    this._upbitConnectModel,
  ) {
    _walletListBaseItem = _walletProvider.getWalletById(_walletId);
    // _prevWalletInitState = _walletProvider.walletInitState;
    _initUtxoAndTags();
    _prevUpdateStatus = _walletProvider.getWalletUpdateInfo(_walletId).utxo;
    _addChangeListener();
    _prevBalance = balance;
  }

  int get balance =>
      _walletProvider.getWalletBalance(_walletListBaseItem.id).total;
  int get prevBalance => _prevBalance;
  int? get bitcoinPriceKrw => _upbitConnectModel.bitcoinPriceKrw;
  bool? get isNetworkOn => _connectProvider.isNetworkOn;

  bool get isUtxoListLoadComplete => _isUtxoListLoadComplete;

  bool get isUtxoTagListEmpty => _utxoTagList.isEmpty;

  UtxoOrder get selectedUtxoOrder => _selectedUtxoOrder;
  String get selectedUtxoTagName => _selectedUtxoTagName;
  UtxoTagProvider get tagProvider => _tagProvider;
  List<UtxoState> get utxoList => _utxoList;

  List<UtxoTag> get utxoTagList => _utxoTagList;

  // 태그 목록 변경을 감지하기 위한 key
  String get utxoTagListKey => _utxoTagList.map((e) => e.name).join(':');

  WalletType get walletType => _walletListBaseItem.walletType;

  bool get isSyncing =>
      _prevUpdateStatus == UpdateStatus.waiting ||
      _prevUpdateStatus == UpdateStatus.syncing;

  void _addChangeListener() {
    _walletProvider.addWalletUpdateListener(
        _walletId, _onWalletUpdateInfoChanged);
  }

  void _onWalletUpdateInfoChanged(WalletUpdateInfo updateInfo) {
    Logger.log('${DateTime.now()}--> 지갑$_walletId 업데이트 체크 (UTXO)');
    if (_prevUpdateStatus != updateInfo.utxo &&
        updateInfo.utxo == UpdateStatus.completed) {
      Logger.log('_getUtxoAndTagList();');

      // 하나의 트랜잭션으로 여러 스크립트에 대한 이벤트가 발생할 경우에 오류 발생.
      // 이벤트 리스너 함수들이 모두 완료되지 않은 상태로 state가 업데이트됨.
      // 결과적으로 화면에서 없어져야 할 UTXO가 남아있거나 새로 생겨야 할 UTXO가 없는 경우가 발생함.
      // 임시로 지연을 통해 이벤트 리스너가 모두 실행되기 전에 동기화 완료 state가 업데이트되는 것을 방지함.
      // TODO: 이벤트 리스너에 대해서 동시성 제어 필요함
      Future.delayed(const Duration(milliseconds: 300), () {
        _getUtxoAndTagList();
        notifyListeners();
      });
    }

    _prevUpdateStatus = updateInfo.utxo;
  }

  void resetUtxoTagsUpdateState() {
    _tagProvider.resetUtxoTagsUpdateState();
  }

  void setSelectedUtxoTagName(String value) {
    _selectedUtxoTagName = value;
    notifyListeners();
  }

  void updateProvider() async {
    if (_tagProvider.isUpdatedTagList) {
      Logger.log('${DateTime.now()} UTXO 태그 업데이트');
      _getUtxoAndTagList();
      _tagProvider.resetUtxoTagsUpdateState();
      notifyListeners();
    }
  }

  void updateUtxoFilter(UtxoOrder selectedUtxoFilter) async {
    _selectedUtxoOrder = selectedUtxoFilter;
    UtxoState.sortUtxo(_utxoList, selectedUtxoFilter);
    notifyListeners();
  }

  void updateUtxoTagList(String utxoId, List<UtxoTag> utxoTagList) {
    final findUtxo = utxoList.firstWhere((item) => item.utxoId == utxoId);
    findUtxo.tags?.clear();
    findUtxo.tags?.addAll(utxoTagList);
    notifyListeners();
  }

  void _getUtxoAndTagList() {
    _isUtxoListLoadComplete = false;
    _utxoList = _walletProvider.getUtxoList(_walletId);
    _utxoTagList = _tagProvider.getUtxoTagList(_walletId);

    final newUtxoTagList = _tagProvider.getUtxoTagList(_walletId);
    _utxoTagList = newUtxoTagList;

    for (var utxo in _utxoList) {
      final tags = _tagProvider.getUtxoTagsByUtxoId(_walletId, utxo.utxoId);

      utxo.tags = tags;
    }
    UtxoState.sortUtxo(_utxoList, _selectedUtxoOrder);
    _isUtxoListLoadComplete = true;
  }

  void refetchFromDB() {
    _getUtxoAndTagList();
    notifyListeners();
  }

  void _initUtxoAndTags() {
    _isUtxoListLoadComplete = false;
    _utxoList = _walletProvider.getUtxoList(_walletId);
    _utxoTagList = _tagProvider.getUtxoTagList(_walletId);

    for (var utxo in _utxoList) {
      final tags = _tagProvider.getUtxoTagsByUtxoId(_walletId, utxo.utxoId);

      utxo.tags = tags;
    }
    _isUtxoListLoadComplete = true;
    UtxoState.sortUtxo(_utxoList, _selectedUtxoOrder);
  }

  List<String> getTimeString(int utxoIndex) {
    if (_utxoList.isEmpty) return [];
    final utxo = _utxoList[utxoIndex];
    final tx = _txProvider.getTransaction(_walletId, utxo.transactionHash);
    if (tx == null) return [];

    return DateTimeUtil.formatTimestamp(tx.timestamp!);
  }

  @override
  void dispose() {
    _walletProvider.removeWalletUpdateListener(
        _walletId, _onWalletUpdateInfoChanged);
    super.dispose();
  }
}
