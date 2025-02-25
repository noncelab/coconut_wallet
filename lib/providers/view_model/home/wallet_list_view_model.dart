import 'dart:async';

import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WalletListViewModel extends ChangeNotifier {
  late final VisibilityProvider _visibilityProvider;
  late WalletProvider _walletProvider;
  late final bool _hasLaunchedAppBefore;
  late bool _isTermsShortcutVisible;
  late bool _isBalanceHidden;
  late final bool _isReviewScreenVisible;
  late WalletInitState _prevWalletInitState;
  late final NodeProvider _nodeProvider;
  late final TransactionProvider _transactionProvider;
  final Map<int, int> _walletBalance = {};
  late StreamSubscription<Map<int, Balance>> _balanceSubscription;
  bool _isFirstSyncFinished = false;

  WalletListViewModel(this._walletProvider, this._visibilityProvider,
      this._isBalanceHidden, this._nodeProvider, this._transactionProvider) {
    _hasLaunchedAppBefore = _visibilityProvider.hasLaunchedBefore;

    _isTermsShortcutVisible = _visibilityProvider.visibleTermsShortcut;
    _isReviewScreenVisible = AppReviewService.shouldShowReviewScreen();
    _prevWalletInitState = _walletProvider.walletInitState;
    // TODO:
    _balanceSubscription =
        _walletProvider.balanceStream.stream.listen(_updateBalance);
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
  bool get shouldShowLoadingIndicator =>
      walletLoadCompleted && !_isFirstSyncFinished;

  bool get walletLoadCompleted =>
      _walletProvider.walletLoadState == WalletLoadState.loadCompleted;
  int get lastUpdateTime => _walletProvider.lastUpdateTime;
  String? get walletInitErrorMessage =>
      _walletProvider.walletInitError?.message;
  WalletInitState get walletInitState => _walletProvider.walletInitState;
  List<WalletListItemBase> get walletItemList => _walletProvider.walletItemList;

  void hideTermsShortcut() {
    _isTermsShortcutVisible = false;
    _visibilityProvider.hideTermsShortcut();
    notifyListeners();
  }

  Future initWallet(
      {int? targetId, int? exceptionalId, bool syncOthers = true}) async {
    _walletProvider.initWallet(
        targetId: targetId,
        exceptionalId: exceptionalId,
        syncOthers: syncOthers);

    for (var walletItem in walletItemList) {
      Logger.log('>>>>> walletItem: ${walletItem.name}');
      // 새로운 내역이 있는지 조회
      final newTxResList = await _nodeProvider.scanNewTransactionResponses(
          walletItem, _walletProvider);

      // 잔액 조회
      final balanceResult = await _nodeProvider.getBalance(walletItem);
      if (balanceResult.isSuccess) {
        _walletProvider.updateWalletAddressList(walletItem,
            balanceResult.value.$1, balanceResult.value.$2, newTxResList);
      }
      notifyListeners();

      // 트랜잭션 내역 조회
      if (newTxResList.isNotEmpty) {
        await _nodeProvider.saveFetchTransactions(
            walletItem, newTxResList, _walletProvider);
      }
      notifyListeners();

      // Utxo 조회
      walletItem.utxoList = await _nodeProvider.fetchUtxos(walletItem);

      notifyListeners();
    }
  }

  Future<void> refreshWallets() async {
    if (!walletLoadCompleted) return;

    await _walletProvider.syncWalletData();
  }

  void onWalletProviderUpdated(WalletProvider walletProvider) {
    if (!_isFirstSyncFinished &&
        walletProvider.walletSyncingState == WalletSyncingState.finished) {
      _isFirstSyncFinished = true;
      notifyListeners();
    }

    _walletProvider = walletProvider;

    // TODO:
    if (_prevWalletInitState != walletProvider.walletInitState) {
      if (walletProvider.walletInitState == WalletInitState.finished) {
        _onWalletInitStateFinished();
      } else if (walletProvider.walletInitState == WalletInitState.error) {
        _onWalletInitStateError();
      }
      _prevWalletInitState = walletProvider.walletInitState;
    }

    notifyListeners();
  }

  void setIsBalanceHidden(bool value) {
    _isBalanceHidden = value;
    notifyListeners();
  }

  void updateAppReviewRequestCondition() async {
    await AppReviewService.increaseAppRunningCountIfRejected();
  }

  void _onWalletInitStateError() {
    vibrateLightDouble();
  }

  void _onWalletInitStateFinished() {
    vibrateLight();
  }

  int? getWalletBalance(int id) {
    Logger.log('--> _walletBalance[id]');
    return _walletBalance[id];
    //return _walletProvider.getWalletBalance(id);
  }

  void onNodeProviderUpdated() {
    notifyListeners();
  }

  @override
  void dispose() {
    _balanceSubscription.cancel();
    return super.dispose();
  }
}
