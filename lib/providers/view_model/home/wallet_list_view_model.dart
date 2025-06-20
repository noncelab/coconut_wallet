import 'dart:async';

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
  late final VisibilityProvider _visibilityProvider;
  late WalletProvider _walletProvider;
  late bool _isTermsShortcutVisible;
  late bool _isBalanceHidden;
  late final bool _isReviewScreenVisible;
  late WalletSubscriptionState _walletSyncingState;
  late final ConnectivityProvider _connectivityProvider;
  late bool? _isNetworkOn;
  Map<int, AnimatedBalanceData> _walletBalance = {};
  bool _isFirstLoaded = false;

  WalletListViewModel(
    this._walletProvider,
    this._visibilityProvider,
    this._isBalanceHidden,
    this._connectivityProvider,
  ) {
    _isTermsShortcutVisible = _visibilityProvider.visibleTermsShortcut;
    _isReviewScreenVisible = AppReviewService.shouldShowReviewScreen();
    _walletSyncingState = _walletProvider.walletSubscriptionState;
    _isNetworkOn = _connectivityProvider.isNetworkOn;
  }

  bool get isBalanceHidden => _isBalanceHidden;
  bool get isReviewScreenVisible => _isReviewScreenVisible;
  bool get isTermsShortcutVisible => _isTermsShortcutVisible;
  bool get shouldShowLoadingIndicator =>
      !_isFirstLoaded &&
      _walletProvider.isAnyBalanceUpdating &&
      _walletProvider.walletSubscriptionState != WalletSubscriptionState.failed;
  List<WalletListItemBase> get walletItemList => _walletProvider.walletItemList;
  bool? get isNetworkOn => _isNetworkOn;

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

    if (_walletSyncingState != walletProvider.walletSubscriptionState) {
      if (walletProvider.walletSubscriptionState == WalletSubscriptionState.completed) {
        vibrateLight();
        if (_isFirstLoaded == false) {
          _isFirstLoaded = true;
        }
      } else if (walletProvider.walletSubscriptionState == WalletSubscriptionState.failed) {
        vibrateLightDouble();
      }
      _walletSyncingState = walletProvider.walletSubscriptionState;
    } else if (_walletSyncingState == WalletSubscriptionState.completed &&
        walletProvider.walletSubscriptionState == WalletSubscriptionState.completed &&
        _isFirstLoaded == false) {
      _isFirstLoaded = true;
    }
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
}
