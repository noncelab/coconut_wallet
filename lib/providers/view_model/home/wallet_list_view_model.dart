import 'dart:async';

import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:flutter/material.dart';

class WalletListViewModel extends ChangeNotifier {
  late final VisibilityProvider _visibilityProvider;
  late WalletProvider _walletProvider;
  late final bool _hasLaunchedAppBefore;
  late bool _isTermsShortcutVisible;
  late bool _isBalanceHidden;
  late final bool _isReviewScreenVisible;
  late WalletSubscriptionState _walletSyncingState;
  late final NodeProvider _nodeProvider;
  late final TransactionProvider _transactionProvider;
  late final ConnectivityProvider _connectivityProvider;
  Map<int, int> _walletBalance = {};
  late StreamSubscription<Map<int, Balance?>> _balanceSubscription;
  late bool? _isNetworkOn;

  WalletListViewModel(
    this._walletProvider,
    this._visibilityProvider,
    this._isBalanceHidden,
    this._nodeProvider,
    this._transactionProvider,
    this._connectivityProvider,
  ) {
    _hasLaunchedAppBefore = _visibilityProvider.hasLaunchedBefore;
    _isTermsShortcutVisible = _visibilityProvider.visibleTermsShortcut;
    _isReviewScreenVisible = AppReviewService.shouldShowReviewScreen();
    _walletSyncingState = _walletProvider.walletSubscriptionState;
    _isNetworkOn = _connectivityProvider.isNetworkOn;
  }

  bool get isBalanceHidden => _isBalanceHidden;
  bool get isOnBoardingVisible => !_hasLaunchedAppBefore;
  bool get isReviewScreenVisible => _isReviewScreenVisible;
  bool get isTermsShortcutVisible => _isTermsShortcutVisible;
  bool get shouldShowLoadingIndicator => _walletProvider.isAnyBalanceUpdating;
  String? get walletInitErrorMessage =>
      _walletProvider.walletInitError?.message;
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
    _walletBalance =
        balanceMap.map((key, balance) => MapEntry(key, balance.total));
  }

  void onWalletProviderUpdated(WalletProvider walletProvider) {
    _walletProvider = walletProvider;
    _updateBalance(walletProvider.walletBalance);
    notifyListeners();

    if (_walletSyncingState != walletProvider.walletSubscriptionState) {
      if (walletProvider.walletSubscriptionState ==
          WalletSubscriptionState.completed) {
        vibrateLight();
      } else if (walletProvider.walletSubscriptionState ==
          WalletSubscriptionState.failed) {
        vibrateLightDouble();
      }
      _walletSyncingState = walletProvider.walletSubscriptionState;
    }
  }

  void setIsBalanceHidden(bool value) {
    _isBalanceHidden = value;
    notifyListeners();
  }

  void updateAppReviewRequestCondition() async {
    await AppReviewService.increaseAppRunningCountIfRejected();
  }

  int? getWalletBalance(int id) {
    return _walletBalance[id];
    //return _walletProvider.getWalletBalance(id);
  }

  void onNodeProviderUpdated() {
    notifyListeners();
  }

  void updateIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  @override
  void dispose() {
    _balanceSubscription.cancel();
    return super.dispose();
  }
}
