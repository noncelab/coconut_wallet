import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:flutter/material.dart';

class WalletListViewModel extends ChangeNotifier {
  late final PreferenceProvider _preferenceProvider;
  late WalletProvider _walletProvider;
  late final bool _hasLaunchedAppBefore;
  late final bool _isEligibleToRequestReview; // TODO:

  WalletListViewModel(this._walletProvider, this._preferenceProvider,
      this._hasLaunchedAppBefore) {
    _isEligibleToRequestReview = false; // TODO:
  }

  bool get isEligibleToRequestReview => _isEligibleToRequestReview;
  bool get showOnBoarding => !_hasLaunchedAppBefore;
  String? get walletInitErrorMessage =>
      _walletProvider.walletInitError?.message;
  WalletInitState get walletInitState => _walletProvider.walletInitState;
  List<WalletListItemBase> get walletItemList => _walletProvider.walletItemList;
  bool get fastLoadDone => _walletProvider.fastLoadDone;

  Future initWallet(
      {int? targetId, int? exceptionalId, bool syncOthers = true}) async {
    await _walletProvider.initWallet(
        targetId: targetId,
        exceptionalId: exceptionalId,
        syncOthers: syncOthers);
  }

  void onWalletProviderUpdated(WalletProvider walletProvider) {
    _walletProvider = walletProvider;
  }
}
