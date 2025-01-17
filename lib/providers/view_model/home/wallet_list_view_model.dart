import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:flutter/material.dart';

class WalletListViewModel extends ChangeNotifier {
  late final PreferenceProvider _preferenceProvider;
  late final WalletProvider _walletProvider;
  late final bool _hasLaunchedAppBefore;
  late final bool _isEligibleToRequestReview; // TODO:

  WalletListViewModel(this._walletProvider, this._preferenceProvider,
      this._hasLaunchedAppBefore) {
    _isEligibleToRequestReview = false; // TODO:
  }

  bool get showOnBoarding => !_hasLaunchedAppBefore;
  bool get isEligibleToRequestReview => _isEligibleToRequestReview;
}
