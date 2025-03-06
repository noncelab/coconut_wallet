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
  late WalletSyncingState _walletSyncingState;
  late WalletInitState _prevWalletInitState;
  late final NodeProvider _nodeProvider;
  late final TransactionProvider _transactionProvider;
  late final ConnectivityProvider _connectivityProvider;
  final Map<int, int> _walletBalance = {};
  late StreamSubscription<Map<int, Balance>> _balanceSubscription;
  bool _isFirstSyncFinished = false;
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
    _walletSyncingState = _walletProvider.walletSyncingState;
    // TODO:
    _balanceSubscription =
        _walletProvider.balanceStream.stream.listen(_updateBalance);

    _isNetworkOn = _connectivityProvider.isNetworkOn;
  }

  void _updateBalance(Map<int, Balance?> newBalance) {
    final balance = newBalance.entries.first.value;
    if (balance != null) {
      _walletBalance[newBalance.keys.first] = balance.total;
      notifyListeners();
    } else {
      _walletBalance.remove(newBalance.keys.first);
    }
  }

  bool get isBalanceHidden => _isBalanceHidden;
  bool get isOnBoardingVisible => !_hasLaunchedAppBefore;
  bool get isReviewScreenVisible => _isReviewScreenVisible;
  bool get isTermsShortcutVisible => _isTermsShortcutVisible;
  bool get shouldShowLoadingIndicator => !_isFirstSyncFinished;
  int get lastUpdateTime => _walletProvider.lastUpdateTime;
  String? get walletInitErrorMessage =>
      _walletProvider.walletInitError?.message;
  WalletInitState get walletInitState => _walletProvider.walletInitState;
  List<WalletListItemBase> get walletItemList => _walletProvider.walletItemList;
  bool? get isNetworkOn => _isNetworkOn;

  void hideTermsShortcut() {
    _isTermsShortcutVisible = false;
    _visibilityProvider.hideTermsShortcut();
    notifyListeners();
  }

  Future<void> refreshWallets() async {
    Logger.log('--> refreshWallet 시작');
    for (var wallet in walletItemList) {
      await _walletProvider.fetchWalletBalance(wallet.id);
    }
    Logger.log('--> refreshWallet 끝');
  }

  void onWalletProviderUpdated(WalletProvider walletProvider) {
    if (!_isFirstSyncFinished &&
        (walletProvider.walletSyncingState == WalletSyncingState.completed ||
            walletProvider.walletSyncingState == WalletSyncingState.failed)) {
      _isFirstSyncFinished = true;
    }

    _walletProvider = walletProvider;
    notifyListeners();

    if (_walletSyncingState != walletProvider.walletSyncingState) {
      if (walletProvider.walletSyncingState == WalletSyncingState.completed) {
        vibrateLight();
      } else if (walletProvider.walletSyncingState ==
          WalletSyncingState.failed) {
        vibrateLightDouble();
      }
      _walletSyncingState = walletProvider.walletSyncingState;
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
