import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
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
  late final PriceProvider _priceProvider;
  late final PreferenceProvider _preferenceProvider;
  late final WalletListItemBase _walletListBaseItem;
  final Stream<WalletUpdateInfo> _syncWalletStateStream;
  StreamSubscription<WalletUpdateInfo>? _syncWalletStateSubscription;
  late final int _walletId;
  WalletSyncState _prevUpdateStatus = WalletSyncState.completed;
  List<UtxoState> _filteredUtxoList = [];
  final List<UtxoState> _confirmedUtxoList = [];
  final Map<String, List<UtxoTag>> _utxoTagMap = {};
  List<UtxoState> _selectedUtxoList = [];

  // balance 애니메이션을 위한 이전 잔액을 담는 변수
  late int _prevBalance;

  List<UtxoState> _utxoList = [];
  late UtxoOrder _selectedUtxoOrder;
  bool _isUtxoListLoadComplete = false;
  String _selectedUtxoTagName = t.all;
  List<UtxoTag> _utxoTagList = [];
  List<UtxoState> get filteredUtxoList => _filteredUtxoList;
  List<UtxoState> get confirmedUtxoList => _confirmedUtxoList;
  int? _cachedSelectedUtxoAmountSum; // 계산식 수행 반복을 방지하기 위해 추가
  UtxoOrder get utxoOrder => _preferenceProvider.utxoSortOrder;

  UtxoListViewModel(
    this._walletId,
    this._walletProvider,
    this._txProvider,
    this._tagProvider,
    this._connectProvider,
    this._priceProvider,
    this._preferenceProvider,
    this._syncWalletStateStream,
  ) {
    _walletListBaseItem = _walletProvider.getWalletById(_walletId);
    _initUtxoAndTags();
    _addChangeListener();
    _prevBalance = balance;

    // 모든 UTXO (locked 포함)를 리스트에 추가
    _walletProvider.getUtxoList(_walletId).fold<int>(0, (sum, utxo) {
      // unspent와 locked 모두 포함
      if (utxo.status == UtxoStatus.unspent || utxo.status == UtxoStatus.locked) {
        _confirmedUtxoList.add(utxo);
      }
      return utxo.status == UtxoStatus.unspent ? sum + utxo.amount : sum;
    });
    _sortConfirmedUtxoList(utxoOrder);
    _initUtxoTagMap();
    _updateFilteredUtxoList();

    _utxoTagList = _tagProvider.getUtxoTagList(_walletId);
  }

  int get balance => _walletProvider.getWalletBalance(_walletListBaseItem.id).total;
  int get prevBalance => _prevBalance;
  int? get bitcoinPriceKrw => _priceProvider.bitcoinPriceKrw;
  bool? get isNetworkOn => _connectProvider.isInternetOn;

  bool get isUtxoListLoadComplete => _isUtxoListLoadComplete;

  bool get isUtxoTagListEmpty => _utxoTagList.isEmpty;

  UtxoOrder get selectedUtxoOrder => _selectedUtxoOrder;
  String get selectedUtxoTagName => _selectedUtxoTagName;
  UtxoTagProvider get tagProvider => _tagProvider;
  List<UtxoState> get utxoList => _utxoList;

  List<UtxoTag> get utxoTagList => _utxoTagList;

  int get selectedUtxoAmountSum {
    _cachedSelectedUtxoAmountSum ??= _calculateTotalAmountOfUtxoList(_selectedUtxoList);

    return _cachedSelectedUtxoAmountSum!;
  }

  List<UtxoState> get selectedUtxoList => _selectedUtxoList;

  // 태그 목록 변경을 감지하기 위한 key
  String get utxoTagListKey => _utxoTagList.map((e) => e.name).join(':');

  WalletType get walletType => _walletListBaseItem.walletType;

  bool get isSyncing => _prevUpdateStatus == WalletSyncState.waiting || _prevUpdateStatus == WalletSyncState.syncing;

  int _calculateTotalAmountOfUtxoList(List<Utxo> utxos) {
    return utxos.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);
  }

  void _addChangeListener() {
    _syncWalletStateSubscription = _syncWalletStateStream.listen(_onWalletUpdateInfoChanged);
  }

  void _onWalletUpdateInfoChanged(WalletUpdateInfo updateInfo) {
    Logger.log('${DateTime.now()}--> 지갑$_walletId 업데이트 체크 (UTXO)');
    if (_prevUpdateStatus != updateInfo.utxo && updateInfo.utxo == WalletSyncState.completed) {
      _getUtxoAndTagList();
    }

    _prevUpdateStatus = updateInfo.utxo;
    notifyListeners();
  }

  void resetUtxoTagsUpdateState() {
    _tagProvider.resetUtxoTagsUpdateState();
  }

  void setSelectedUtxoTagName(String value) {
    _selectedUtxoTagName = value;
    for (var utxo in _confirmedUtxoList) {
      _utxoTagMap[utxo.utxoId] = _tagProvider.getUtxoTagsByUtxoId(_walletId, utxo.utxoId);
    }
    _updateFilteredUtxoList();
    notifyListeners();
  }

  void selectTaggedUtxo() {
    _updateFilteredUtxoList();
    setSelectedUtxoList(_filteredUtxoList);
  }

  void setSelectedUtxoList(List<UtxoState> utxoList) {
    _selectedUtxoList = utxoList;
    _cachedSelectedUtxoAmountSum = null;
    notifyListeners();
  }

  void deselectTaggedUtxo() {
    clearUtxoList();
  }

  void clearUtxoList() {
    _selectedUtxoList = [];
    _cachedSelectedUtxoAmountSum = 0;
    notifyListeners();
  }

  void _updateFilteredUtxoList() {
    if (_selectedUtxoTagName == t.all) {
      // 모든 UTXO 표시
      _filteredUtxoList = List<UtxoState>.from(_confirmedUtxoList);
    } else if (_selectedUtxoTagName == t.utxo_detail_screen.utxo_locked) {
      // 잠금된 UTXO만 표시
      _filteredUtxoList = _confirmedUtxoList.where((utxo) => utxo.isLocked).toList();
    } else if (_selectedUtxoTagName == t.change) {
      // 체인지 UTXO만 표시
      _filteredUtxoList = _confirmedUtxoList.where((utxo) => utxo.isChange).toList();
    } else {
      // 태그 기반 필터링
      _filteredUtxoList =
          _confirmedUtxoList.where((utxo) {
            final tags = _utxoTagMap[utxo.utxoId];
            return tags != null && tags.any((tag) => tag.name == _selectedUtxoTagName);
          }).toList();
    }
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
    await _preferenceProvider.setLastUtxoOrder(selectedUtxoFilter);
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
    notifyListeners();
  }

  void refetchFromDB() {
    _getUtxoAndTagList();
    notifyListeners();
  }

  void _initUtxoTagMap() {
    for (var (element) in _confirmedUtxoList) {
      final tags = _tagProvider.getUtxoTagsByUtxoId(_walletId, element.utxoId);
      _utxoTagMap[element.utxoId] = tags;
    }
  }

  void _sortConfirmedUtxoList(UtxoOrder basis) {
    // 먼저 status에 따라 분리 (unlock된 것 먼저, locked는 뒤에)
    _confirmedUtxoList.sort((a, b) {
      // locked 상태 우선순위: unspent가 먼저, locked가 나중에
      if (a.status != b.status) {
        if (a.status == UtxoStatus.unspent && b.status == UtxoStatus.locked) {
          return -1; // a가 먼저
        } else if (a.status == UtxoStatus.locked && b.status == UtxoStatus.unspent) {
          return 1; // b가 먼저
        }
      }

      // 같은 status 내에서는 기존 정렬 기준 적용
      return 0;
    });

    // unlock된 UTXO들만 따로 정렬
    final unlockedUtxos = _confirmedUtxoList.where((utxo) => utxo.status == UtxoStatus.unspent).toList();
    final lockedUtxos = _confirmedUtxoList.where((utxo) => utxo.status == UtxoStatus.locked).toList();

    // 각각 별도로 정렬
    UtxoState.sortUtxo(unlockedUtxos, basis);
    UtxoState.sortUtxo(lockedUtxos, basis);

    // 다시 합치기 (unlock 먼저, lock 나중에)
    _confirmedUtxoList.clear();
    _confirmedUtxoList.addAll(unlockedUtxos);
    _confirmedUtxoList.addAll(lockedUtxos);
  }

  void _initUtxoAndTags() {
    _isUtxoListLoadComplete = false;
    _utxoList = _walletProvider.getUtxoList(_walletId);
    _utxoTagList = _tagProvider.getUtxoTagList(_walletId);
    _selectedUtxoOrder = _preferenceProvider.utxoSortOrder;

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

    return DateTimeUtil.formatTimestamp(tx.timestamp);
  }

  @override
  void dispose() {
    _syncWalletStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> updateSelectedUtxosStatus(List<String> utxoIds, UtxoStatus status) async {
    try {
      // DB에서 한번에 상태 업데이트
      await _walletProvider.updateUtxoStatus(_walletId, utxoIds, status);

      // 메모리 리스트도 일괄 업데이트
      for (final utxo in _utxoList) {
        if (utxoIds.contains(utxo.utxoId)) {
          utxo.status = status;
        }
      }

      // affected 목록
      final affectedUtxos = _utxoList.where((u) => utxoIds.contains(u.utxoId)).toList();

      // selected 리스트 갱신
      if (status == UtxoStatus.locked) {
        if (_selectedUtxoTagName == t.utxo_detail_screen.utxo_locked) {
          _selectedUtxoList = affectedUtxos;
        } else {
          _selectedUtxoList.removeWhere((u) => utxoIds.contains(u.utxoId));
        }
      } else if (status == UtxoStatus.unspent) {
        if (_selectedUtxoTagName != t.utxo_detail_screen.utxo_locked) {
          _selectedUtxoList
            ..removeWhere((u) => utxoIds.contains(u.utxoId))
            ..addAll(affectedUtxos);
        } else {
          _selectedUtxoList.removeWhere((u) => utxoIds.contains(u.utxoId));
        }
      }

      // confirmed 리스트 갱신
      _confirmedUtxoList
        ..clear()
        ..addAll(
          _walletProvider
              .getUtxoList(_walletId)
              .where((u) => u.status == UtxoStatus.unspent || u.status == UtxoStatus.locked),
        );

      // 정렬 + 필터링
      _sortConfirmedUtxoList(_selectedUtxoOrder);
      _updateFilteredUtxoList();

      // UI 갱신
      notifyListeners();
    } catch (e) {
      debugPrint('UTXO 상태 업데이트 실패: $e');
      rethrow;
    }
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    notifyListeners();
  }

  void addSelectUtxo(UtxoState utxo) {
    selectedUtxoList.add(utxo);
    _cachedSelectedUtxoAmountSum = null;
    notifyListeners();
  }

  void removeSelectUtxo(UtxoState utxo) {
    selectedUtxoList.remove(utxo);
    _cachedSelectedUtxoAmountSum = null;
    notifyListeners();
  }
}
