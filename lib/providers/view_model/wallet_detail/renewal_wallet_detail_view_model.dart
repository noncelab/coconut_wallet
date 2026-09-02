import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/constants/security_warning_constants.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/faucet/faucet_history.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/faucet_service.dart';
import 'package:coconut_wallet/services/model/request/faucet_request.dart';
import 'package:coconut_wallet/services/model/response/faucet_response.dart';
import 'package:coconut_wallet/services/model/error/default_error_response.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/foundation.dart';

class RenewalWalletDetailViewModel extends ChangeNotifier {
  static const int recentTransactionLimit = 3;
  static const _minimumRefreshIndicatorDuration = Duration(milliseconds: 700);
  static const _targetSuggestionDismissDuration = Duration(days: 30);

  final int _walletId;
  final WalletProvider _walletProvider;
  final TransactionProvider _transactionProvider;
  final SharedPrefsRepository _sharedPrefs;
  final Faucet _faucetService = Faucet();
  late final StreamSubscription<WalletUpdateInfo> _walletUpdateSubscription;
  late final StreamSubscription<NodeSyncState> _nodeSyncStateSubscription;
  WalletUpdateInfo? _walletUpdateInfo;
  late NodeSyncState _nodeSyncState;
  bool _isRequestingFaucet = false;
  late bool _isWalletSyncing;
  bool _isRefreshing = false;
  BitcoinUnit _currentUnit;
  final Set<RenewalWalletDetailSecurityWarningType> _dismissedWarningsThisSession = {};
  RenewalWalletDetailSecurityWarningType? _nextWarningAfterDismissal;
  bool _isDisposed = false;

  RenewalWalletDetailViewModel(
    this._walletId,
    this._walletProvider,
    this._transactionProvider,
    NodeProvider nodeProvider, {
    required BitcoinUnit initialUnit,
    SharedPrefsRepository? sharedPrefs,
  }) : _currentUnit = initialUnit,
       _sharedPrefs = sharedPrefs ?? SharedPrefsRepository() {
    _walletUpdateInfo = nodeProvider.state.registeredWallets[_walletId];
    _nodeSyncState = nodeProvider.state.nodeSyncState;
    _isWalletSyncing = _calculateIsWalletSyncing();
    _transactionProvider.initTxList(_walletId);
    _walletProvider.addListener(_handleWalletChanged);
    _transactionProvider.addListener(_handleTransactionChanged);
    _walletUpdateSubscription = nodeProvider.getWalletStateStream(_walletId).listen(_handleWalletUpdate);
    _nodeSyncStateSubscription = nodeProvider.syncStateStream.listen(_handleNodeSyncState);
  }

  int get walletId => _walletId;
  WalletProvider get walletProvider => _walletProvider;
  WalletItemBase get wallet => _walletProvider.getWalletById(_walletId);
  int get balance => _walletProvider.getWalletBalance(_walletId).total;
  int get utxoCount => _walletProvider.getUtxoList(_walletId).length;
  int? get targetSats => _sharedPrefs.getWalletTargetSats(_walletId);
  bool get shouldShowTargetSuggestion {
    if (targetSats != null) return false;
    final hiddenUntil = _sharedPrefs.getInt(SharedPrefKeys.walletTargetSuggestionHiddenUntil(_walletId));
    return hiddenUntil == 0 || DateTime.now().millisecondsSinceEpoch >= hiddenUntil;
  }

  List<TransactionRecord> get transactions => List.unmodifiable(_transactionProvider.txList);
  List<TransactionRecord> get recentTransactions =>
      List.unmodifiable(_transactionProvider.txList.take(recentTransactionLimit));
  bool get hasTransactions => _transactionProvider.txList.isNotEmpty;
  bool get isRequestingFaucet => _isRequestingFaucet;
  bool get isWalletSyncing => _isWalletSyncing;
  bool get isRefreshing => _isRefreshing;
  BitcoinUnit get currentUnit => _currentUnit;
  String get receiveAddress => _walletProvider.getReceiveAddress(_walletId).address;
  String get receiveAddressIndex => _walletProvider.getReceiveAddress(_walletId).derivationPath.split('/').last;
  double get targetProgress {
    final target = targetSats;
    if (target == null || target == 0) return 0;
    final progress = balance / target;
    return progress < 0 ? 0 : progress;
  }

  bool get isTargetExceeded => targetSats != null && balance > targetSats!;
  int get targetExcessSats => isTargetExceeded ? balance - targetSats! : 0;

  String get targetProgressPercent {
    final percent = targetProgress * 100;
    return percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent.toStringAsFixed(1);
  }

  /// 현재 잔액에서 거래를 역산해 만든 목표 달성률의 시간순 지점입니다.
  List<double> get targetProgressHistory {
    final target = targetSats;
    final currentProgress = targetProgress;
    if (target == null || target <= 0 || _transactionProvider.txList.isEmpty) return [0, currentProgress];

    final newestFirst = [..._transactionProvider.txList]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    var historicalBalance = balance;
    final newestFirstBalances = <int>[historicalBalance];
    for (final transaction in newestFirst) {
      switch (transaction.transactionType) {
        case TransactionType.received:
          historicalBalance -= transaction.amount.abs();
          break;
        case TransactionType.sent:
        case TransactionType.self:
          historicalBalance += transaction.amount.abs();
          break;
        case TransactionType.unknown:
          continue;
      }
      historicalBalance = historicalBalance.clamp(0, 1 << 62);
      newestFirstBalances.add(historicalBalance);
    }

    return newestFirstBalances.reversed.map((value) => (value / target).clamp(0.0, double.infinity)).toList(growable: false);
  }

  void toggleUnit() {
    _currentUnit = _currentUnit.next;
    notifyListeners();
  }

  Future<void> requestTestBitcoin(
    String address,
    double requestAmount,
    void Function(bool success, String message) onResult,
  ) async {
    _isRequestingFaucet = true;
    notifyListeners();
    try {
      final response = await _faucetService.getTestCoin(FaucetRequest(address: address, amount: requestAmount));
      if (response is FaucetResponse) {
        onResult(true, t.faucet_request);
        _updateFaucetRecord();
      } else if (response is DefaultErrorResponse && response.error == 'TOO_MANY_REQUEST_FAUCET') {
        onResult(false, t.faucet_already_request);
      } else {
        onResult(false, t.faucet_failed);
      }
    } catch (_) {
      onResult(false, t.faucet_failed);
    } finally {
      _isRequestingFaucet = false;
      notifyListeners();
    }
  }

  void _updateFaucetRecord() {
    var record = _sharedPrefs.getFaucetHistoryWithId(_walletId);
    if (!record.isToday) {
      record = FaucetRecord(id: _walletId, dateTime: DateTime.now().millisecondsSinceEpoch, count: 0);
    }
    _sharedPrefs.saveFaucetHistory(
      record.copyWith(dateTime: DateTime.now().millisecondsSinceEpoch, count: record.count + 1),
    );
  }

  Future<void> refresh() async {
    if (_isRefreshing || _isDisposed) return;

    _isRefreshing = true;
    notifyListeners();
    final stopwatch = Stopwatch()..start();
    try {
      _transactionProvider.initTxList(_walletId);
      notifyListeners();
    } finally {
      final remaining = _minimumRefreshIndicatorDuration - stopwatch.elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
      if (!_isDisposed) {
        _isRefreshing = false;
        notifyListeners();
      }
    }
  }

  RenewalWalletDetailSecurityWarningType? getSecurityWarningType({required bool isAppLockEnabled}) {
    if (!wallet.hasLocalKey || balance <= 0) return null;
    if (!(wallet.hotWalletMetadata?.backupVerified ?? false) &&
        canShowSecurityWarning(RenewalWalletDetailSecurityWarningType.unbackedHotWallet)) {
      return RenewalWalletDetailSecurityWarningType.unbackedHotWallet;
    }
    if (!isAppLockEnabled && canShowSecurityWarning(RenewalWalletDetailSecurityWarningType.appLock)) {
      return RenewalWalletDetailSecurityWarningType.appLock;
    }
    return null;
  }

  bool canShowSecurityWarning(RenewalWalletDetailSecurityWarningType type) {
    if (_dismissedWarningsThisSession.contains(type)) return false;
    final dismissedAt = _sharedPrefs.getInt(type.dismissedAtKey);
    return dismissedAt == 0 ||
        DateTime.now().millisecondsSinceEpoch - dismissedAt >= kSecurityWarningDismissDuration.inMilliseconds;
  }

  bool shouldUseShortWarningDelay(RenewalWalletDetailSecurityWarningType type) => _nextWarningAfterDismissal == type;

  Future<void> dismissSecurityWarning(
    RenewalWalletDetailSecurityWarningType type, {
    required bool showNextWarning,
  }) async {
    _dismissedWarningsThisSession.add(type);
    await _sharedPrefs.setInt(type.dismissedAtKey, DateTime.now().millisecondsSinceEpoch);
    if (_isDisposed) return;
    _nextWarningAfterDismissal = showNextWarning ? RenewalWalletDetailSecurityWarningType.appLock : null;
    notifyListeners();
  }

  void reloadWalletMetadata() => notifyListeners();

  Future<void> dismissTargetSuggestion() async {
    await _sharedPrefs.setInt(
      SharedPrefKeys.walletTargetSuggestionHiddenUntil(_walletId),
      DateTime.now().add(_targetSuggestionDismissDuration).millisecondsSinceEpoch,
    );
    if (!_isDisposed) notifyListeners();
  }

  void _handleWalletChanged() {
    if (_walletProvider.walletItemList.any((wallet) => wallet.id == _walletId)) {
      notifyListeners();
    }
  }

  void _handleTransactionChanged() => notifyListeners();

  void _handleWalletUpdate(WalletUpdateInfo updateInfo) {
    _walletUpdateInfo = updateInfo;
    _updateWalletSyncingState();
    if (updateInfo.transaction == WalletSyncState.completed) {
      _transactionProvider.initTxList(_walletId);
    }
  }

  void _handleNodeSyncState(NodeSyncState nodeSyncState) {
    _nodeSyncState = nodeSyncState;
    _updateWalletSyncingState();
  }

  bool _calculateIsWalletSyncing() {
    if (_nodeSyncState == NodeSyncState.completed || _nodeSyncState == NodeSyncState.failed) {
      return false;
    }

    final walletUpdateInfo = _walletUpdateInfo;
    if (walletUpdateInfo == null) {
      return _nodeSyncState == NodeSyncState.init || _nodeSyncState == NodeSyncState.syncing;
    }

    return walletUpdateInfo.balance != WalletSyncState.completed ||
        walletUpdateInfo.transaction != WalletSyncState.completed;
  }

  void _updateWalletSyncingState() {
    final isWalletSyncing = _calculateIsWalletSyncing();
    if (_isWalletSyncing == isWalletSyncing || _isDisposed) return;
    _isWalletSyncing = isWalletSyncing;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _walletUpdateSubscription.cancel();
    _nodeSyncStateSubscription.cancel();
    _walletProvider.removeListener(_handleWalletChanged);
    _transactionProvider.removeListener(_handleTransactionChanged);
    super.dispose();
  }
}

enum RenewalWalletDetailSecurityWarningType { unbackedHotWallet, appLock }

extension on RenewalWalletDetailSecurityWarningType {
  String get dismissedAtKey => switch (this) {
    RenewalWalletDetailSecurityWarningType.unbackedHotWallet => SharedPrefKeys.kUnbackedHotWalletWarningDismissedAt,
    RenewalWalletDetailSecurityWarningType.appLock => SharedPrefKeys.kAppLockWarningDismissedAt,
  };
}
