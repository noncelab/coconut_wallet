import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

typedef AnimatedBalanceDataGetter = AnimatedBalanceData Function(int id);
typedef BalanceGetter = int Function(int id);
typedef FakeBalanceGetter = int? Function(int id);

class WalletListViewModel extends ChangeNotifier {
  WalletProvider _walletProvider;
  final Stream<NodeSyncState> _syncNodeStateStream;
  late final ConnectivityProvider _connectivityProvider;
  late PreferenceProvider _preferenceProvider;
  late bool? _isNetworkOn;
  Map<int, AnimatedBalanceData> _walletBalance = {};

  bool _isFirstLoaded = false;
  NodeSyncState _nodeSyncState = NodeSyncState.syncing;
  StreamSubscription<NodeSyncState>? _syncNodeStateSubscription;

  // late final StreamSubscription _preferenceSubscription;
  late List<int> _walletOrder = [];
  List<int> get walletOrder => _walletOrder;
  // 임시 지갑 순서 ID 목록(편집용)
  List<int> tempWalletOrder = [];

  late List<int> _starredWalletIds = [];
  List<int> get starredWalletIds => _starredWalletIds;
  // 임시 즐겨찾기 지갑 ID 목록(편집용)
  List<int> tempStarredWalletIds = [];

  late List<int> _excludedFromTotalBalanceWalletIds = [];
  List<int> get excludedFromTotalBalanceWalletIds => _excludedFromTotalBalanceWalletIds;

  bool _isEditMode = false;
  bool get isEditMode => _isEditMode;

  WalletListViewModel(
    this._walletProvider,
    this._connectivityProvider,
    this._syncNodeStateStream,
    this._preferenceProvider,
  ) {
    _isNetworkOn = _connectivityProvider.isNetworkOn;
    _walletOrder = _preferenceProvider.walletOrder;
    _starredWalletIds = _preferenceProvider.starredWalletIds;
    _excludedFromTotalBalanceWalletIds = _preferenceProvider.excludedFromTotalBalanceWalletIds;
    _syncNodeStateSubscription = _syncNodeStateStream.listen(_handleNodeSyncState);
    _walletBalance = _walletProvider
        .fetchWalletBalanceMap()
        .map((key, balance) => MapEntry(key, AnimatedBalanceData(balance.total, balance.total)));
    _walletProvider.walletLoadStateNotifier.addListener(updateWalletBalances);
    _preferenceProvider.addListener(_onPreferenceChanged);
  }

  void _onPreferenceChanged() {
    onPreferenceProviderUpdated();
  }

  bool get shouldShowLoadingIndicator => !_isFirstLoaded && _nodeSyncState == NodeSyncState.syncing;
  List<WalletListItemBase> get walletItemList {
    final walletList = _walletProvider.walletItemListNotifier.value;
    final order = _preferenceProvider.walletOrder;

    if (order.isEmpty) {
      return walletList;
    }

    final walletMap = {for (var wallet in walletList) wallet.id: wallet};
    var orderedMap = order.map((id) => walletMap[id]).whereType<WalletListItemBase>().toList();
    return orderedMap;
  }

  bool? get isNetworkOn => _isNetworkOn;
  Map<int, AnimatedBalanceData> get walletBalanceMap => _walletBalance;

  void _handleNodeSyncState(NodeSyncState syncState) {
    if (_nodeSyncState != syncState) {
      if (syncState == NodeSyncState.completed) {
        if (!_isFirstLoaded) {
          _isFirstLoaded = true;
          vibrateLight();
        }
        updateWalletBalances();
      } else if (syncState == NodeSyncState.failed) {
        vibrateLightDouble();
      }
      _nodeSyncState = syncState;
      notifyListeners();
    } else if (_nodeSyncState == NodeSyncState.completed &&
        syncState == NodeSyncState.completed &&
        _isFirstLoaded == false) {
      _isFirstLoaded = true;
      _nodeSyncState = syncState;
    }
  }

  void setEditMode(bool isEditMode) {
    _isEditMode = isEditMode;
    if (isEditMode) {
      // 최신 starredWalletIds를 PreferenceProvider에서 다시 읽어옴
      _starredWalletIds = List.from(_preferenceProvider.starredWalletIds);

      tempStarredWalletIds =
          walletItemList.where((w) => _starredWalletIds.contains(w.id)).map((w) => w.id).toList();

      tempWalletOrder = walletItemList.map((w) => w.id).toList();
    }
    notifyListeners();
  }

  void onPreferenceProviderUpdated() {
    debugPrint('aaaaaaaaa');

    /// 지갑 순서 변경 체크
    if (!const ListEquality().equals(_walletOrder, _preferenceProvider.walletOrder)) {
      _walletOrder = _preferenceProvider.walletOrder;
    }

    /// 총 잔액에서 제외할 지갑 목록 변경 체크
    if (!const SetEquality().equals(_excludedFromTotalBalanceWalletIds.toSet(),
        _preferenceProvider.excludedFromTotalBalanceWalletIds.toSet())) {
      _excludedFromTotalBalanceWalletIds = _preferenceProvider.excludedFromTotalBalanceWalletIds;
    }

    notifyListeners();
  }

  Future<void> updateWalletBalances() async {
    final updatedWalletBalance = _updateBalanceMap(_walletProvider.fetchWalletBalanceMap());
    _walletBalance = updatedWalletBalance;
    notifyListeners();
  }

  Map<int, AnimatedBalanceData> _updateBalanceMap(Map<int, Balance> balanceMap) {
    return balanceMap.map((key, balance) {
      final prev = _walletBalance[key]?.current ?? 0;
      return MapEntry(
        key,
        AnimatedBalanceData(balance.total, prev),
      );
    });
  }

  void onWalletProviderUpdated(WalletProvider walletProvider) {
    _walletProvider = walletProvider;
    notifyListeners();
  }

  void onNodeProviderUpdated() {
    notifyListeners();
  }

  void updateIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  bool isWalletListChanged(List<WalletListItemBase> oldList, List<WalletListItemBase> newList,
      Map<int, AnimatedBalanceData> walletBalanceMap) {
    if (oldList.length != newList.length) return true;

    bool walletListChanged = oldList.asMap().entries.any((entry) {
      int index = entry.key;
      return entry.value.toString() != newList[index].toString();
    });

    bool balanceChanged = walletBalanceMap.entries.any((entry) {
      AnimatedBalanceData balanceData = entry.value;
      return balanceData.previous != balanceData.current;
    });

    return walletListChanged || balanceChanged;
  }

  void toggleTempStarred(int walletId) {
    if (tempStarredWalletIds.contains(walletId)) {
      tempStarredWalletIds = List.from(tempStarredWalletIds)..remove(walletId);
    } else {
      if (tempStarredWalletIds.length < 5) {
        tempStarredWalletIds = List.from(tempStarredWalletIds)..add(walletId);
      }
    }
    notifyListeners();
  }

  void clearTempDatas() {
    tempStarredWalletIds.clear();
    tempWalletOrder.clear();
    notifyListeners();
  }

  /// 임시값을 실제 walletList에 반영
  Future<void> applyTempDatasToWallets() async {
    if (!hasWalletOrderChanged && !hasStarredChanged) return;

    if (hasWalletOrderChanged) {
      await _preferenceProvider.setWalletOrder(tempWalletOrder);

      final walletMap = {for (var wallet in walletItemList) wallet.id: wallet};
      _walletProvider.walletItemListNotifier.value =
          tempWalletOrder.map((id) => walletMap[id]).whereType<WalletListItemBase>().toList();
    }
    if (hasStarredChanged) {
      await _preferenceProvider.setStarredWalletIds(tempStarredWalletIds);
      _starredWalletIds = _preferenceProvider.starredWalletIds;
    }

    notifyListeners();
  }

  bool get hasStarredChanged => !const SetEquality().equals(
        tempStarredWalletIds.toSet(),
        _preferenceProvider.starredWalletIds.toSet(),
      );

  bool get hasWalletOrderChanged => !const ListEquality().equals(
        tempWalletOrder,
        _preferenceProvider.walletOrder,
      );

  void reorderTempWalletOrder(int oldIndex, int newIndex) {
    final item = tempWalletOrder.removeAt(oldIndex);
    tempWalletOrder.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    notifyListeners();
  }

  void updatePreferenceProvider(PreferenceProvider preferenceProvider) {
    if (_preferenceProvider != preferenceProvider) {
      _preferenceProvider.removeListener(_onPreferenceChanged);
      _preferenceProvider = preferenceProvider;
      _preferenceProvider.addListener(_onPreferenceChanged);
      onPreferenceProviderUpdated();
    }
  }

  @override
  void dispose() {
    _syncNodeStateSubscription?.cancel();
    _preferenceProvider.removeListener(_onPreferenceChanged);
    super.dispose();
  }
}
