import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:flutter/material.dart';

typedef AnimatedBalanceDataGetter = AnimatedBalanceData Function(int id);
typedef BalanceGetter = int Function(int id);

class WalletListViewModel extends ChangeNotifier {
  final VisibilityProvider _visibilityProvider;
  WalletProvider _walletProvider;
  final Stream<NodeSyncState> _syncStateStream;
  late bool _isTermsShortcutVisible;
  late bool _isBalanceHidden;
  late final bool _isReviewScreenVisible;
  late final ConnectivityProvider _connectivityProvider;
  late bool? _isNetworkOn;
  Map<int, AnimatedBalanceData> _walletBalance = {};
  bool _isFirstLoaded = false;
  NodeSyncState _nodeSyncState = NodeSyncState.syncing;

  // Stream subscription for NodeSyncState
  StreamSubscription<NodeSyncState>? _syncStateSubscription;

  WalletListViewModel(
    this._walletProvider,
    this._visibilityProvider,
    this._isBalanceHidden,
    this._connectivityProvider,
    this._syncStateStream,
  ) {
    _isTermsShortcutVisible = _visibilityProvider.visibleTermsShortcut;
    _isReviewScreenVisible = AppReviewService.shouldShowReviewScreen();
    _isNetworkOn = _connectivityProvider.isNetworkOn;

    // Stream 구독 시작
    _subscribeToSyncStateStream();
  }

  bool get isBalanceHidden => _isBalanceHidden;
  bool get isReviewScreenVisible => _isReviewScreenVisible;
  bool get isTermsShortcutVisible => _isTermsShortcutVisible;
  bool get shouldShowLoadingIndicator => !_isFirstLoaded && _nodeSyncState == NodeSyncState.syncing;
  List<WalletListItemBase> get walletItemList => _walletProvider.walletItemList;
  bool? get isNetworkOn => _isNetworkOn;

  /// NodeSyncState Stream 구독
  void _subscribeToSyncStateStream() {
    _syncStateSubscription = _syncStateStream.listen((syncState) {
      if (_nodeSyncState != syncState) {
        if (syncState == NodeSyncState.completed) {
          if (!_isFirstLoaded) {
            _isFirstLoaded = true;
            vibrateLight();
          }
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
    });
  }

  void hideTermsShortcut() {
    _isTermsShortcutVisible = false;
    _visibilityProvider.hideTermsShortcut();
    notifyListeners();
  }

  Future<void> refreshWallets() async {
    _updateBalance(_walletProvider.fetchWalletBalanceMap());
    notifyListeners();
  }

  void _updateBalance(Map<int, Balance> balanceMap) {
    // todo: remove debug print
    // debugPrint('뷰모델!! _updateBalance: ${balanceMap.entries.map(
    //       (e) => '${e.key}: ${e.value.total}',
    //     ).toList()}');

    _walletBalance = balanceMap.map((key, balance) {
      final prev = _walletBalance[key]?.current ?? 0;
      return MapEntry(
        key,
        AnimatedBalanceData(balance.total, prev),
      );
    });
  }

  void onWalletProviderUpdated(WalletProvider walletProvider) {
    _walletProvider = walletProvider;
    _updateBalance(walletProvider.walletBalance);
    notifyListeners();
  }

  void setIsBalanceHidden(bool value) {
    _isBalanceHidden = value;
    notifyListeners();
  }

  void updateAppReviewRequestCondition() async {
    await AppReviewService.increaseAppRunningCountIfRejected();
  }

  AnimatedBalanceData getWalletBalance(int id) {
    return _walletBalance[id] ?? AnimatedBalanceData(0, 0);
  }

  void onNodeProviderUpdated() {
    notifyListeners();
  }

  void updateIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  bool isWalletListChanged(List<WalletListItemBase> oldList, List<WalletListItemBase> newList,
      Map<int, int> previousWalletBalance, BalanceGetter getUpdatedBalance) {
    if (oldList.length != newList.length) return true;

    return oldList.asMap().entries.any((entry) {
          int index = entry.key;
          return entry.value.toString() != newList[index].toString();
        }) ||
        previousWalletBalance.entries.any((entry) {
          int id = entry.key;
          return entry.value != getUpdatedBalance(id);
        });
  }

  @override
  void dispose() {
    _syncStateSubscription?.cancel();
    super.dispose();
  }
}
