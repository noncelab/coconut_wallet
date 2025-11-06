import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

typedef AnimatedBalanceDataGetter = AnimatedBalanceData Function(int id);
typedef BalanceGetter = int Function(int id);
typedef FakeBalanceGetter = int? Function(int id);

class WalletHomeViewModel extends ChangeNotifier {
  late final VisibilityProvider _visibilityProvider;
  WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;
  final Stream<NodeSyncState> _syncNodeStateStream;
  late final PreferenceProvider _preferenceProvider;
  late bool _isTermsShortcutVisible;
  late bool _isBalanceHidden;
  late final bool _isReviewScreenVisible;
  late final ConnectivityProvider _connectivityProvider;
  late bool? _isNetworkOn;
  Map<int, AnimatedBalanceData> _walletBalance = {};
  Map<int, dynamic> _fakeBalanceMap = {};
  int? _fakeBalanceTotalAmount;
  bool _isFirstLoaded = false;
  bool _isEmptyFavoriteWallet = false; // 즐겨찾기 설정된 지갑이 없는지 여부
  NodeSyncState _nodeSyncState = NodeSyncState.syncing;
  StreamSubscription<NodeSyncState>? _syncNodeStateSubscription;
  List<WalletListItemBase> _favoriteWallets = [];

  late List<int> _excludedFromTotalBalanceWalletIds = [];
  List<int> get excludedFromTotalBalanceWalletIds => _excludedFromTotalBalanceWalletIds;

  WalletHomeViewModel(
    this._walletProvider,
    this._preferenceProvider,
    this._visibilityProvider,
    this._connectivityProvider,
    this._nodeProvider,
  ) : _syncNodeStateStream = _nodeProvider.syncStateStream {
    _isTermsShortcutVisible = _visibilityProvider.visibleTermsShortcut;
    _isReviewScreenVisible = AppReviewService.shouldShowReviewScreen();
    _isNetworkOn = _connectivityProvider.isNetworkOn;
    _syncNodeStateSubscription = _syncNodeStateStream.listen(_handleNodeSyncState);
    _walletBalance = _walletProvider.fetchWalletBalanceMap().map(
      (key, balance) => MapEntry(key, AnimatedBalanceData(balance.total, balance.total)),
    );
    _walletProvider.walletLoadStateNotifier.addListener(updateWalletBalances);

    // NodeProvider의 변경사항 listening 추가
    _nodeProvider.addListener(_onNodeProviderChanged);

    _isBalanceHidden = _preferenceProvider.isBalanceHidden;
    _fakeBalanceTotalAmount = _preferenceProvider.fakeBalanceTotalAmount;
    _fakeBalanceMap = _preferenceProvider.getFakeBalanceMap();
    _excludedFromTotalBalanceWalletIds = _preferenceProvider.excludedFromTotalBalanceWalletIds;
  }

  void _onNodeProviderChanged() {
    // NodeProvider의 hasConnectionError 등이 변경되었을 때 UI 업데이트
    notifyListeners();
  }

  bool get isEmptyFavoriteWallet => _isEmptyFavoriteWallet;
  bool get isBalanceHidden => _isBalanceHidden;
  bool get isReviewScreenVisible => _isReviewScreenVisible;
  bool get isTermsShortcutVisible => _isTermsShortcutVisible;
  bool get shouldShowLoadingIndicator => !_isFirstLoaded && _nodeSyncState == NodeSyncState.syncing;
  List<WalletListItemBase> get walletItemList {
    // 지갑 목록을 가져오고, 순서가 설정되어 있다면 그 순서대로 정렬
    // 홈에서는 즐겨찾기가 되어있는 지갑만 보여야 하기 때문에 필터링 작업도 수행
    final walletList = _walletProvider.walletItemListNotifier.value;
    final order = _preferenceProvider.walletOrder;
    if (order.isEmpty) {
      return walletList;
    }

    final walletMap = {for (var wallet in walletList) wallet.id: wallet};
    var orderedMap = order.map((id) => walletMap[id]).whereType<WalletListItemBase>().toList();
    return orderedMap;
  }

  List<WalletListItemBase> get favoriteWallets => _favoriteWallets;

  bool? get isNetworkOn => _isNetworkOn;
  int? get fakeBalanceTotalAmount => _fakeBalanceTotalAmount;
  Map<int, dynamic> get fakeBalanceMap => _fakeBalanceMap;
  Map<int, AnimatedBalanceData> get walletBalanceMap => _walletBalance;

  /// 네트워크 상태를 구분하여 반환
  NetworkStatus get networkStatus {
    // print(
    //     'DEBUG - _isNetworkOn: $_isNetworkOn, _nodeSyncState: $_nodeSyncState, hasConnectionError: ${_nodeProvider.hasConnectionError}');

    if (!(_isNetworkOn ?? false)) {
      return NetworkStatus.offline;
    }

    if (_nodeSyncState == NodeSyncState.failed || _nodeProvider.hasConnectionError) {
      return NetworkStatus.connectionFailed;
    }

    return NetworkStatus.online;
  }

  WalletListItemBase getWalletById(int walletId) {
    return _walletProvider.getWalletById(walletId);
  }

  void _handleNodeSyncState(NodeSyncState syncState) {
    // Logger.log('DEBUG - _handleNodeSyncState called with: $syncState');
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
      // Logger.log('DEBUG - _nodeSyncState updated to: $_nodeSyncState');
      notifyListeners();
    } else if (_nodeSyncState == NodeSyncState.completed &&
        syncState == NodeSyncState.completed &&
        _isFirstLoaded == false) {
      _isFirstLoaded = true;
      _nodeSyncState = syncState;
    }
  }

  void hideTermsShortcut() {
    _isTermsShortcutVisible = false;
    _visibilityProvider.hideTermsShortcut();
    notifyListeners();
  }

  Future<void> onRefresh() async {
    updateWalletBalances();

    if (networkStatus != NetworkStatus.connectionFailed) {
      return;
    }

    _nodeProvider.reconnect();
  }

  void updateWalletBalances() {
    final updatedWalletBalance = _updateBalanceMap(_walletProvider.fetchWalletBalanceMap());
    _walletBalance = updatedWalletBalance;
    notifyListeners();
  }

  Map<int, AnimatedBalanceData> _updateBalanceMap(Map<int, Balance> balanceMap) {
    return balanceMap.map((key, balance) {
      final prev = _walletBalance[key]?.current ?? 0;
      return MapEntry(key, AnimatedBalanceData(balance.total, prev));
    });
  }

  void onWalletProviderUpdated(WalletProvider walletProvider) {
    _walletProvider = walletProvider;
    notifyListeners();
  }

  void onPreferenceProviderUpdated() {
    /// 잔액 숨기기 변동 체크
    if (_isBalanceHidden != _preferenceProvider.isBalanceHidden) {
      setIsBalanceHidden(_preferenceProvider.isBalanceHidden);
    }

    /// 가짜 잔액 총량 변동 체크 (on/off 판별)
    if (_fakeBalanceTotalAmount != _preferenceProvider.fakeBalanceTotalAmount) {
      _setFakeBlancTotalAmount(_preferenceProvider.fakeBalanceTotalAmount);
      _setFakeBlanceMap(_preferenceProvider.getFakeBalanceMap());
    }

    /// 지갑별 가짜 잔액 변동 체크
    if (_fakeBalanceMap != _preferenceProvider.getFakeBalanceMap()) {
      // map이 변경되는 경우는 totalAmount가 변경되는 것과 관련이 없음
      _setFakeBlanceMap(_preferenceProvider.getFakeBalanceMap());
    }

    /// 지갑 즐겨찾기 변동 체크
    if (_favoriteWallets.map((w) => w.id).toList().toString() != _preferenceProvider.favoriteWalletIds.toString() &&
        walletItemList.isNotEmpty) {
      loadFavoriteWallets();
    }

    /// 총 잔액에서 제외할 지갑 목록 변경 체크
    if (!const SetEquality().equals(
      _excludedFromTotalBalanceWalletIds.toSet(),
      _preferenceProvider.excludedFromTotalBalanceWalletIds.toSet(),
    )) {
      _excludedFromTotalBalanceWalletIds = _preferenceProvider.excludedFromTotalBalanceWalletIds;
    }
    notifyListeners();
  }

  void setIsBalanceHidden(bool value) {
    _preferenceProvider.changeIsBalanceHidden(value);
    _isBalanceHidden = value;
    notifyListeners();
  }

  void _setFakeBlancTotalAmount(int? value) {
    _fakeBalanceTotalAmount = value;
    notifyListeners();
  }

  void clearFakeBlanceTotalAmount() {
    _preferenceProvider.clearFakeBalanceTotalAmount();
    _preferenceProvider.changeIsFakeBalanceActive(false); // 가짜잔액 초기화시 비활성화도 같이 수행(Wallet_home 에서만)
    notifyListeners();
  }

  void _setFakeBlanceMap(Map<int, dynamic> value) {
    _fakeBalanceMap = value;
    notifyListeners();
  }

  void updateAppReviewRequestCondition() async {
    await AppReviewService.increaseAppRunningCountIfRejected();
  }

  int? getFakeBalance(int id) {
    return _fakeBalanceMap[id] ?? _fakeBalanceTotalAmount;
  }

  int getHomeFakeBalanceTotal() {
    if (_fakeBalanceTotalAmount == null) return 0;

    int totalAmount = 0;

    // excludedFromTotalBalanceWalletIds에 포함되지 않은 지갑들의 가짜 잔액을 더함
    for (final wallet in walletItemList) {
      if (!_excludedFromTotalBalanceWalletIds.contains(wallet.id)) {
        final fakeBalance = _fakeBalanceMap[wallet.id];
        if (fakeBalance != null && fakeBalance is num) {
          totalAmount += fakeBalance.toInt();
        }
      }
    }

    return totalAmount;
  }

  void onNodeProviderUpdated() {
    notifyListeners();
  }

  void updateIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  bool isWalletListChanged(
    List<WalletListItemBase> oldList,
    List<WalletListItemBase> newList,
    Map<int, AnimatedBalanceData> walletBalanceMap,
  ) {
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

  Future<void> loadFavoriteWallets() async {
    if (_walletProvider.walletItemListNotifier.value.isEmpty) return;

    final ids = _preferenceProvider.favoriteWalletIds;

    final wallets =
        ids
            .map((id) => _walletProvider.walletItemListNotifier.value.firstWhereOrNull((w) => w.id == id))
            .whereType<WalletListItemBase>()
            .toList();

    _favoriteWallets = wallets;

    _isEmptyFavoriteWallet = wallets.isEmpty;

    notifyListeners();
  }

  @override
  void dispose() {
    _syncNodeStateSubscription?.cancel();
    _nodeProvider.removeListener(_onNodeProviderChanged);
    super.dispose();
  }
}
