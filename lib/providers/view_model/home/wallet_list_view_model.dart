import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

typedef AnimatedBalanceDataGetter = AnimatedBalanceData Function(int id);
typedef BalanceGetter = int Function(int id);
typedef FakeBalanceGetter = int? Function(int id);

class WalletListViewModel extends ChangeNotifier {
  final ValueNotifier<bool> loadingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> pinCheckNotifier = ValueNotifier(false);
  final SharedPrefsRepository sharedPrefs = SharedPrefsRepository();

  WalletProvider _walletProvider;
  late final ConnectivityProvider _connectivityProvider;
  late final AuthProvider _authProvider;
  late final NodeProvider _nodeProvider;
  late final PriceProvider _priceProvider;
  late Stream<NodeSyncState> _syncNodeStateStream;
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

  late List<int> _favoriteWalletIds = [];
  List<int> get favoriteWalletIds => _favoriteWalletIds;
  // 임시 즐겨찾기 지갑 ID 목록(편집용)
  List<int> tempFavoriteWalletIds = [];

  late List<int> _excludedFromTotalBalanceWalletIds = [];
  List<int> get excludedFromTotalBalanceWalletIds => _excludedFromTotalBalanceWalletIds;

  bool _isEditMode = false;
  bool get isEditMode => _isEditMode;

  WalletListViewModel(
    this._walletProvider,
    this._connectivityProvider,
    this._authProvider,
    this._nodeProvider,
    this._preferenceProvider,
    this._priceProvider,
  ) {
    _isNetworkOn = _connectivityProvider.isNetworkOn;
    _walletOrder = _preferenceProvider.walletOrder;
    _favoriteWalletIds = _preferenceProvider.favoriteWalletIds;
    _excludedFromTotalBalanceWalletIds = _preferenceProvider.excludedFromTotalBalanceWalletIds;
    _syncNodeStateStream = _nodeProvider.syncStateStream;
    _syncNodeStateSubscription = _syncNodeStateStream.listen(_handleNodeSyncState);
    _walletBalance = _walletProvider
        .fetchWalletBalanceMap()
        .map((key, balance) => MapEntry(key, AnimatedBalanceData(balance.total, balance.total)));
    _walletProvider.walletLoadStateNotifier.addListener(updateWalletBalances);
    _preferenceProvider.addListener(_onPreferenceChanged);
    _priceProvider.addListener(_updateBitcoinPrice);
  }

  void _updateBitcoinPrice() {
    notifyListeners();
  }

  String getBitcoinPrice(int satoshiAmount) {
    return _priceProvider.getFiatPrice(satoshiAmount);
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
        if (!_nodeProvider.isServerChanging) {
          vibrateLightDouble();
        }
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
      // 최신 favoriteWalletIds를 PreferenceProvider에서 다시 읽어옴
      _favoriteWalletIds = List.from(_preferenceProvider.favoriteWalletIds);

      tempFavoriteWalletIds =
          walletItemList.where((w) => _favoriteWalletIds.contains(w.id)).map((w) => w.id).toList();

      tempWalletOrder = walletItemList.map((w) => w.id).toList();
    }
    notifyListeners();
  }

  void onPreferenceProviderUpdated() {
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

  void toggleTempFavorite(int walletId) {
    if (tempFavoriteWalletIds.contains(walletId)) {
      tempFavoriteWalletIds = List.from(tempFavoriteWalletIds)..remove(walletId);
    } else {
      if (tempFavoriteWalletIds.length < 5) {
        tempFavoriteWalletIds = List.from(tempFavoriteWalletIds)..add(walletId);
      }
    }
    notifyListeners();
  }

  void clearTempDatas() {
    tempFavoriteWalletIds.clear();
    tempWalletOrder.clear();
    notifyListeners();
  }

  /// 임시값을 실제 walletList에 반영
  Future<void> applyTempDatasToWallets() async {
    if (!hasWalletOrderChanged && !hasFavoriteChanged) return;

    final deletedWalletIds =
        _preferenceProvider.walletOrder.where((id) => !tempWalletOrder.contains(id)).toList();
    await _handleAuthFlow(
      onComplete: () async {
        if (hasWalletOrderChanged) {
          // 삭제 여부 판단
          if (tempWalletOrder.length != _preferenceProvider.walletOrder.length) {
            setLoadingNotifier(true);

            await _deleteWallets(deletedWalletIds);
            setLoadingNotifier(false);
          }
          await _preferenceProvider.setWalletOrder(tempWalletOrder);

          final walletMap = {for (var wallet in walletItemList) wallet.id: wallet};
          _walletProvider.walletItemListNotifier.value =
              tempWalletOrder.map((id) => walletMap[id]).whereType<WalletListItemBase>().toList();
        }
        if (hasFavoriteChanged) {
          await _preferenceProvider.setFavoriteWalletIds(tempFavoriteWalletIds);
          _favoriteWalletIds = _preferenceProvider.favoriteWalletIds;
        }
        setEditMode(false);
        notifyListeners();
      },
      hasWalletDeleted: deletedWalletIds.isNotEmpty,
    );
  }

  VoidCallback? _pendingAuthCompleteCallback;

  Future<void> _handleAuthFlow(
      {required VoidCallback onComplete, required bool hasWalletDeleted}) async {
    if (!hasWalletDeleted) {
      // 지갑이 삭제된 경우가 아니라면 pinCheck 생략
      onComplete();
      return;
    }
    if (!_authProvider.isAuthEnabled) {
      onComplete();
      return;
    }

    if (await _authProvider.isBiometricsAuthValid()) {
      onComplete();
      return;
    }

    _pendingAuthCompleteCallback = onComplete;
    setPincheckNotifier(true);
    notifyListeners();
  }

  void handleAuthCompletion() {
    if (_pendingAuthCompleteCallback != null) {
      _pendingAuthCompleteCallback!();
      _pendingAuthCompleteCallback = null;
    }
  }

  Future<void> _deleteWallets(List<int> deletedWalletIds) async {
    for (int i = 0; i < deletedWalletIds.length; i++) {
      int walletId = deletedWalletIds[i];
      await sharedPrefs.removeFaucetHistory(walletId);
      await _walletProvider.deleteWallet(walletId);
    }
    _nodeProvider.reconnect();
    _walletProvider.notifyListeners();
  }

  bool get hasFavoriteChanged => !const SetEquality().equals(
        tempFavoriteWalletIds.toSet(),
        _preferenceProvider.favoriteWalletIds.toSet(),
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

  void removeTempWalletOrderByWalletId(int walletId) async {
    final orderIndex = tempWalletOrder.indexOf(walletId);
    final starIndex = tempFavoriteWalletIds.indexOf(walletId);
    if (orderIndex != -1) {
      tempWalletOrder.removeAt(orderIndex);
    }
    if (starIndex != -1) {
      tempFavoriteWalletIds.removeAt(starIndex);
    }
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

  void setLoadingNotifier(bool value) {
    loadingNotifier.value = value;
  }

  void setPincheckNotifier(bool value) {
    pinCheckNotifier.value = value;
  }

  @override
  void dispose() {
    _syncNodeStateSubscription?.cancel();
    _preferenceProvider.removeListener(_onPreferenceChanged);
    _priceProvider.removeListener(_updateBitcoinPrice);
    super.dispose();
  }
}
