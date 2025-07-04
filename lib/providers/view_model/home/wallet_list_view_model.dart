import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:flutter/material.dart';

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
  List<int> starredWalletIds = [];

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
    if (starredWalletIds.contains(walletId)) {
      starredWalletIds = List.from(starredWalletIds)..remove(walletId);
    } else {
      if (starredWalletIds.length < 5) {
        starredWalletIds = List.from(starredWalletIds)..add(walletId);
      }
    }
    notifyListeners();
  }

  /// 임시값을 실제 isStarred 필드에 반영
  void applyTempStarredToWallets() {
    for (var wallet in walletItemList) {
      wallet.isStarred = starredWalletIds.contains(wallet.id);
    }
    notifyListeners();
  }

  /// 편집 진입 시 현재 상태를 temp로 복사
  void cacheCurrentStarredWallets() {
    starredWalletIds = walletItemList.where((w) => w.isStarred).map((w) => w.id).toList();
  }

  @override
  void dispose() {
    _syncNodeStateSubscription?.cancel();
    super.dispose();
  }
}
