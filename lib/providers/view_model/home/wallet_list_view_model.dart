import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:flutter/material.dart';

class WalletListViewModel extends ChangeNotifier {
  late final VisibilityProvider _visibilityProvider;
  late WalletProvider _walletProvider;
  late final bool _hasLaunchedAppBefore;
  late bool _visibleTermsShortcut;
  late bool _isBalanceHidden;
  late final bool _showReviewScreen;

  WalletListViewModel(
      this._walletProvider, this._visibilityProvider, this._isBalanceHidden) {
    _hasLaunchedAppBefore = _visibilityProvider.hasLaunchedBefore;
    _visibleTermsShortcut = _visibilityProvider.visibleTermsShortcut;
    _showReviewScreen = AppReviewService.shouldShowReviewScreen();
  }

  bool get fastLoadDone => _walletProvider.fastLoadDone;
  bool get visibleTermsShortcut => _visibleTermsShortcut;
  bool get isBalanceHidden => _isBalanceHidden;
  bool get showReviewScreen => _showReviewScreen;

  int get lastUpdateTime => _walletProvider.lastUpdateTime;
  bool get showOnBoarding => !_hasLaunchedAppBefore;
  String? get walletInitErrorMessage =>
      _walletProvider.walletInitError?.message;
  WalletInitState get walletInitState => _walletProvider.walletInitState;
  List<WalletListItemBase> get walletItemList => _walletProvider.walletItemList;

  Future initWallet(
      {int? targetId, int? exceptionalId, bool syncOthers = true}) async {
    return await _walletProvider.initWallet(
        targetId: targetId,
        exceptionalId: exceptionalId,
        syncOthers: syncOthers);
  }

  void hideTermsShortcut() {
    _visibleTermsShortcut = false;
    _visibilityProvider.hideTermsShortcut();
    notifyListeners();
  }

  void updateAppReviewRequestCondition() async {
    await AppReviewService.increaseAppRunningCountIfRejected();
  }

  void setIsBalanceHidden(bool value) {
    _isBalanceHidden = value;
    notifyListeners();
  }

  void onWalletProviderUpdated(WalletProvider walletProvider) {
    _walletProvider = walletProvider;
    notifyListeners();
  }
}
