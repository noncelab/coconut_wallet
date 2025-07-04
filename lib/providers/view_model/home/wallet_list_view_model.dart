import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
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
  late bool? _isNetworkOn;
  Map<int, AnimatedBalanceData> _walletBalance = {};

  bool _isFirstLoaded = false;
  NodeSyncState _nodeSyncState = NodeSyncState.syncing;
  StreamSubscription<NodeSyncState>? _syncNodeStateSubscription;

  // 임시 즐겨찾기 지갑 ID 목록(편집용)
  List<int> tempStarredWalletIds = [];

  List<WalletListItemBase> tempWalletList = [];

  WalletListViewModel(
    this._walletProvider,
    this._connectivityProvider,
    this._syncNodeStateStream,
  ) {
    _isNetworkOn = _connectivityProvider.isNetworkOn;
    _syncNodeStateSubscription = _syncNodeStateStream.listen(_handleNodeSyncState);
    _walletBalance = _walletProvider
        .fetchWalletBalanceMap()
        .map((key, balance) => MapEntry(key, AnimatedBalanceData(balance.total, balance.total)));
    _walletProvider.walletLoadStateNotifier.addListener(updateWalletBalances);
  }

  bool get shouldShowLoadingIndicator => !_isFirstLoaded && _nodeSyncState == NodeSyncState.syncing;
  List<WalletListItemBase> get walletItemList => _walletProvider.walletItemListNotifier.value;
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
    tempWalletList.clear();
    notifyListeners();
  }

  /// 임시값을 실제 walletList에 반영
  void applyTempDatasToWallets() {
    // TODO: 실제 WalletProvider에 있는 walletItemList을 업데이트하는 로직이 필요합니다. (Realm 업데이트도 고려해야 함))
    walletItemList
      ..clear()
      ..addAll(tempWalletList);
    for (var wallet in walletItemList) {
      wallet.isStarred = tempStarredWalletIds.contains(wallet.id);
    }
    notifyListeners();
  }

  /// 편집 진입 시 현재 상태를 temp로 복사
  void cacheCurrentWalletsState() {
    tempStarredWalletIds = walletItemList.where((w) => w.isStarred).map((w) => w.id).toList();
    tempWalletList = List.from(walletItemList);
  }

  bool get hasStarredChanged => !const SetEquality().equals(
        tempStarredWalletIds.toSet(),
        walletItemList.where((w) => w.isStarred).map((w) => w.id).toSet(),
      );

  bool get hasWalletOrderChanged => !const ListEquality().equals(
        tempWalletList,
        walletItemList,
      );

  @override
  void dispose() {
    _syncNodeStateSubscription?.cancel();
    super.dispose();
  }
}
