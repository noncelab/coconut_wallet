import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/foundation.dart';

class RenewalWalletDetailViewModel extends ChangeNotifier {
  static const int recentTransactionLimit = 3;

  final int _walletId;
  final WalletProvider _walletProvider;
  final TransactionProvider _transactionProvider;
  final SharedPrefsRepository _sharedPrefs;
  late final StreamSubscription<WalletUpdateInfo> _walletUpdateSubscription;

  RenewalWalletDetailViewModel(
    this._walletId,
    this._walletProvider,
    this._transactionProvider,
    NodeProvider nodeProvider, {
    SharedPrefsRepository? sharedPrefs,
  }) : _sharedPrefs = sharedPrefs ?? SharedPrefsRepository() {
    _transactionProvider.initTxList(_walletId);
    _walletProvider.addListener(_handleWalletChanged);
    _transactionProvider.addListener(_handleTransactionChanged);
    _walletUpdateSubscription = nodeProvider.getWalletStateStream(_walletId).listen(_handleWalletUpdate);
  }

  int get walletId => _walletId;
  WalletItemBase get wallet => _walletProvider.getWalletById(_walletId);
  int get balance => _walletProvider.getWalletBalance(_walletId).total;
  int get utxoCount => _walletProvider.getUtxoList(_walletId).length;
  int? get targetSats => _sharedPrefs.getWalletTargetSats(_walletId);
  List<TransactionRecord> get transactions => List.unmodifiable(_transactionProvider.txList);
  List<TransactionRecord> get recentTransactions =>
      List.unmodifiable(_transactionProvider.txList.take(recentTransactionLimit));
  bool get hasTransactions => _transactionProvider.txList.isNotEmpty;

  Future<void> refresh() async {
    _transactionProvider.initTxList(_walletId);
    notifyListeners();
  }

  void reloadWalletMetadata() => notifyListeners();

  void _handleWalletChanged() {
    if (_walletProvider.walletItemList.any((wallet) => wallet.id == _walletId)) {
      notifyListeners();
    }
  }

  void _handleTransactionChanged() => notifyListeners();

  void _handleWalletUpdate(WalletUpdateInfo updateInfo) {
    if (updateInfo.transaction == WalletSyncState.completed) {
      _transactionProvider.initTxList(_walletId);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _walletUpdateSubscription.cancel();
    _walletProvider.removeListener(_handleWalletChanged);
    _transactionProvider.removeListener(_handleTransactionChanged);
    super.dispose();
  }
}
