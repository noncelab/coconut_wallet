import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/preference/home_feature.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

typedef AnimatedBalanceDataGetter = AnimatedBalanceData Function(int id);
typedef BalanceGetter = int Function(int id);
typedef FakeBalanceGetter = int? Function(int id);

class WalletHomeViewModel extends ChangeNotifier {
  late final VisibilityProvider _visibilityProvider;
  WalletProvider _walletProvider;
  final Stream<NodeSyncState> _syncNodeStateStream;
  final Stream<BlockTimestamp?> _currentBlockStream;
  late final PreferenceProvider _preferenceProvider;
  late bool _isTermsShortcutVisible;
  late bool _isBalanceHidden;
  late final bool _isReviewScreenVisible;
  late final ConnectivityProvider _connectivityProvider;
  late bool? _isNetworkOn;
  Map<int, AnimatedBalanceData> _walletBalance = {};
  Map<int, dynamic> _fakeBalanceMap = {};
  int? _fakeBalanceTotalAmount;
  bool _isFirstLoaded = false;
  bool _isEmptyFavoriteWallet = false; // 즐겨찾기 설정된 지갑이 없는지 여부
  NodeSyncState _nodeSyncState = NodeSyncState.syncing;
  StreamSubscription<NodeSyncState>? _syncNodeStateSubscription;
  StreamSubscription<BlockTimestamp?>? _currentBlockSubscription;
  List<WalletListItemBase> _favoriteWallets = [];
  final List<HomeFeature> _homeFeatures = [];

  late List<int> _excludedFromTotalBalanceWalletIds = [];
  List<int> get excludedFromTotalBalanceWalletIds => _excludedFromTotalBalanceWalletIds;

  late WalletAddress _receiveAddress;

  // 현재 블록 높이 상태
  BlockTimestamp? _currentBlock;

  BlockTimestamp? get currentBlock => _currentBlock;
  int? get currentBlockHeight => _currentBlock?.height;

  bool _isFetchingLatestTx = false;
  bool _isLatestTxAnalysisRunning = false;

  Map<int, List<TransactionRecord>> _recentTransactions = {};
  Map<int, List<TransactionRecord>> get recentTransactions => _recentTransactions;

  WalletHomeViewModel(this._walletProvider, this._preferenceProvider, this._visibilityProvider,
      this._connectivityProvider, this._syncNodeStateStream, this._currentBlockStream) {
    _isTermsShortcutVisible = _visibilityProvider.visibleTermsShortcut;
    _isReviewScreenVisible = AppReviewService.shouldShowReviewScreen();
    _isNetworkOn = _connectivityProvider.isNetworkOn;
    _syncNodeStateSubscription = _syncNodeStateStream.listen(_handleNodeSyncState);
    _currentBlockSubscription = _currentBlockStream.listen(_handleCurrentBlockUpdate);

    _walletBalance = _walletProvider
        .fetchWalletBalanceMap()
        .map((key, balance) => MapEntry(key, AnimatedBalanceData(balance.total, balance.total)));
    _walletProvider.walletLoadStateNotifier.addListener(updateWalletBalancesAndRecentTxs);

    _isBalanceHidden = _preferenceProvider.isBalanceHidden;
    _fakeBalanceTotalAmount = _preferenceProvider.fakeBalanceTotalAmount;
    _fakeBalanceMap = _preferenceProvider.getFakeBalanceMap();
    _excludedFromTotalBalanceWalletIds = _preferenceProvider.excludedFromTotalBalanceWalletIds;
  }

  bool get isEmptyFavoriteWallet => _isEmptyFavoriteWallet;
  bool get isBalanceHidden => _isBalanceHidden;
  bool get isReviewScreenVisible => _isReviewScreenVisible;
  bool get isTermsShortcutVisible => _isTermsShortcutVisible;
  bool get shouldShowLoadingIndicator => !_isFirstLoaded && _nodeSyncState == NodeSyncState.syncing;
  List<WalletListItemBase> get walletItemList {
    // 지갑 목록을 가져오고, 순서가 설정되어 있다면 그 순서대로 정렬
    // 홈에서는 즐겨찾기가 되어있는 지갑만 보여야 하기 때문에 필터링 작업도 수행
    final walletList = _walletProvider.walletItemListNotifier.value;
    final order = _preferenceProvider.walletOrder;
    if (order.isEmpty) {
      return walletList;
    }

    final walletMap = {for (var wallet in walletList) wallet.id: wallet};
    var orderedMap = order.map((id) => walletMap[id]).whereType<WalletListItemBase>().toList();
    return orderedMap;
  }

  List<WalletListItemBase> get favoriteWallets => _favoriteWallets;
  List<HomeFeature> get homeFeatures => _homeFeatures;

  bool? get isNetworkOn => _isNetworkOn;
  int? get fakeBalanceTotalAmount => _fakeBalanceTotalAmount;
  Map<int, dynamic> get fakeBalanceMap => _fakeBalanceMap;
  Map<int, AnimatedBalanceData> get walletBalanceMap => _walletBalance;

  String get derivationPath => _receiveAddress.derivationPath;
  String get receiveAddressIndex => _receiveAddress.derivationPath.split('/').last;
  String get receiveAddress => _receiveAddress.address;

  WalletListItemBase getWalletById(int walletId) {
    return _walletProvider.getWalletById(walletId);
  }

  void _handleNodeSyncState(NodeSyncState syncState) {
    if (_nodeSyncState != syncState) {
      if (syncState == NodeSyncState.completed) {
        if (!_isFirstLoaded) {
          _isFirstLoaded = true;
          vibrateLight();
        }
        updateWalletBalancesAndRecentTxs();
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
  }

  void _handleCurrentBlockUpdate(BlockTimestamp? currentBlock) {
    _currentBlock = currentBlock;
    Logger.log('WalletHomeViewModel: 현재 블록 높이 업데이트 - ${currentBlock?.height}');
    // latest tx 조회 및 analysis 수행
    getPendingAndRecent7DaysTransactions(currentBlock?.height);
    notifyListeners();
  }

  void hideTermsShortcut() {
    _isTermsShortcutVisible = false;
    _visibilityProvider.hideTermsShortcut();
    notifyListeners();
  }

  Future<void> updateWalletBalancesAndRecentTxs() async {
    final updatedWalletBalance = _updateBalanceMap(_walletProvider.fetchWalletBalanceMap());
    _walletBalance = updatedWalletBalance;

    /// 임의로 여기서 호출
    getPendingAndRecent7DaysTransactions(currentBlock?.height);
    getRecentTransactionAnalysis(30);
    notifyListeners();
  }

  Map<int, AnimatedBalanceData> _updateBalanceMap(Map<int, Balance> balanceMap) {
    return balanceMap.map((key, balance) {
      final prev = _walletBalance[key]?.current ?? 0;
      return MapEntry(
        key,
        AnimatedBalanceData(balance.total, prev),
      );
    });
  }

  void onWalletProviderUpdated(WalletProvider walletProvider) {
    _walletProvider = walletProvider;
    notifyListeners();
  }

  void onPreferenceProviderUpdated() {
    /// 잔액 숨기기 변동 체크
    if (_isBalanceHidden != _preferenceProvider.isBalanceHidden) {
      setIsBalanceHidden(_preferenceProvider.isBalanceHidden);
    }

    /// 가짜 잔액 총량 변동 체크 (on/off 판별)
    if (_fakeBalanceTotalAmount != _preferenceProvider.fakeBalanceTotalAmount) {
      _setFakeBlancTotalAmount(_preferenceProvider.fakeBalanceTotalAmount);
      _setFakeBlanceMap(_preferenceProvider.getFakeBalanceMap());
    }

    /// 지갑별 가짜 잔액 변동 체크
    if (_fakeBalanceMap != _preferenceProvider.getFakeBalanceMap()) {
      // map이 변경되는 경우는 totalAmount가 변경되는 것과 관련이 없음
      _setFakeBlanceMap(_preferenceProvider.getFakeBalanceMap());
    }

    /// 지갑 즐겨찾기 변동 체크
    if (_favoriteWallets.map((w) => w.id).toList().toString() !=
            _preferenceProvider.favoriteWalletIds.toString() &&
        walletItemList.isNotEmpty) {
      loadFavoriteWallets();
    }

    /// 홈 기능 설정(HomeFeatures) 변동 체크
    loadHomeFeatures();

    /// 총 잔액에서 제외할 지갑 목록 변경 체크
    if (!const SetEquality().equals(_excludedFromTotalBalanceWalletIds.toSet(),
        _preferenceProvider.excludedFromTotalBalanceWalletIds.toSet())) {
      _excludedFromTotalBalanceWalletIds = _preferenceProvider.excludedFromTotalBalanceWalletIds;
    }
    notifyListeners();
  }

  void setIsBalanceHidden(bool value) {
    _preferenceProvider.changeIsBalanceHidden(value);
    _isBalanceHidden = value;
    notifyListeners();
  }

  void _setFakeBlancTotalAmount(int? value) {
    _fakeBalanceTotalAmount = value;
    notifyListeners();
  }

  void clearFakeBlanceTotalAmount() {
    _preferenceProvider.clearFakeBalanceTotalAmount();
    _preferenceProvider.changeIsFakeBalanceActive(false); // 가짜잔액 초기화시 비활성화도 같이 수행(Wallet_home 에서만)
    notifyListeners();
  }

  void _setFakeBlanceMap(Map<int, dynamic> value) {
    _fakeBalanceMap = value;
    notifyListeners();
  }

  void updateAppReviewRequestCondition() async {
    await AppReviewService.increaseAppRunningCountIfRejected();
  }

  int? getFakeBalance(int id) {
    return _fakeBalanceMap[id] ?? _fakeBalanceTotalAmount;
  }

  int? getFakeTotalBalance() {
    return _fakeBalanceTotalAmount;
  }

  void onNodeProviderUpdated() {
    notifyListeners();
  }

  void updateIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  bool isWalletListChanged(List<WalletListItemBase> oldList, List<WalletListItemBase> newList,
      Map<int, AnimatedBalanceData> walletBalanceMap) {
    if (oldList.length != newList.length) return true;

    bool walletListChanged = oldList.asMap().entries.any((entry) {
      int index = entry.key;
      return entry.value.toString() != newList[index].toString();
    });

    bool balanceChanged = walletBalanceMap.entries.any((entry) {
      AnimatedBalanceData balanceData = entry.value;
      return balanceData.previous != balanceData.current;
    });

    return walletListChanged || balanceChanged;
  }

  Future<void> loadFavoriteWallets() async {
    if (_walletProvider.walletItemListNotifier.value.isEmpty) return;

    final ids = _preferenceProvider.favoriteWalletIds;

    final wallets = ids
        .map((id) =>
            _walletProvider.walletItemListNotifier.value.firstWhereOrNull((w) => w.id == id))
        .whereType<WalletListItemBase>()
        .toList();

    _favoriteWallets = wallets;

    _isEmptyFavoriteWallet = wallets.isEmpty;

    notifyListeners();
  }

  Future<void> loadHomeFeatures() async {
    final features = _preferenceProvider.homeFeatures;
    _homeFeatures
      ..clear()
      ..addAll(features);
    notifyListeners();
  }

  void setReceiveAddress(int walletId) {
    _receiveAddress = _walletProvider.getReceiveAddress(walletId);
    Logger.log('--> 리시브주소: ${_receiveAddress.address}');
  }

  // 필요한 경우 호출
  void getPendingAndRecent7DaysTransactions(int? blockHeight) {
    if (blockHeight == null || _isFetchingLatestTx) return;

    // 홈 화면에 표시한 지갑 목록 아이디
    _isFetchingLatestTx = true;

    final walletIds = walletItemList.map((w) => w.id).toList();
    final transactions = _walletProvider.getPendingAnd7DaysAgoTransactions(walletIds, blockHeight);
    _recentTransactions = transactions;

    // recentTransactions 로그 출력
    for (var entry in _recentTransactions.entries) {
      Logger.log('WalletHomeViewModel: 지갑 ID ${entry.key} - 트랜잭션 개수: ${entry.value.length}');
      // 개별 트랜잭션의 해시와 value 출력
      for (var tx in entry.value) {
        Logger.log(
            '\tTxHash: ${tx.transactionHash}, Type: ${tx.transactionType.name}, Amount: ${tx.amount}');
      }
    }

    _isFetchingLatestTx = false;
  }

  // 필요한 경우 호출
  void getRecentTransactionAnalysis(int days) {
    if (_isLatestTxAnalysisRunning) return;

    _isLatestTxAnalysisRunning = true;
    // 최근 n days 동안의 트랜잭션을 분석한 결과
    // 조회 기간 내 트랜잭션 개수
    // 조회 기간 내 트랜잭션의 받은 총 금액
    // 조회 기간 내 트랜잭션의 보낸 총 금액
    final walletIds = walletItemList.map((w) => w.id).toList();

    if (currentBlock?.height == null) return;
    final currentBlockHeight = currentBlock!.height;

    final transactions = _walletProvider.getConfirmedTransactionRecordListWithin(
        walletIds, currentBlockHeight, days);

    final receivedTxs =
        transactions.where((t) => t.transactionType == TransactionType.received).toList();
    final sentTxs = transactions.where((t) => t.transactionType == TransactionType.sent).toList();
    final selfTxs = transactions.where((t) => t.transactionType == TransactionType.self).toList();

    final receivedAmount = receivedTxs.fold(0, (sum, t) => sum + t.amount);
    final sentAmount = sentTxs.fold(0, (sum, t) => sum + t.amount);
    final selfAmount = selfTxs.fold(0, (sum, t) => sum + t.amount);

    final totalAmount = receivedAmount + sentAmount + selfAmount;
    final totalTransactionCount = receivedTxs.length + sentTxs.length + selfTxs.length;

    Logger.log('WalletHomeViewModel: 최근 $days일 동안의 트랜잭션 분석 결과');
    Logger.log('WalletHomeViewModel: ${totalAmount.abs()}${totalAmount > 0 ? ' 증가했어요' : ' 감소했어요'}');
    // UTC 기간 출력 : 30일 전 - 오늘 yy.mm.dd 형식으로 출력
    final startDate = DateTime.now().subtract(Duration(days: days)).toUtc();
    final endDate = DateTime.now().toUtc();

    Logger.log(
        'WalletHomeViewModel: 기간: ${startDate.toLocal().toString().split(' ')[0]} ~ ${endDate.toLocal().toString().split(' ')[0]} | 트랜잭션 $totalTransactionCount 회');
    Logger.log('WalletHomeViewModel: ⬇️ Received: ${receivedTxs.length}회 $receivedAmount ');
    Logger.log('WalletHomeViewModel: ⬆️ Sent: ${sentTxs.length}회 $sentAmount ');
    Logger.log('WalletHomeViewModel: 🔄 Self: ${selfTxs.length}회 $selfAmount ');

    _isLatestTxAnalysisRunning = false;
  }

  @override
  void dispose() {
    _currentBlockSubscription?.cancel();
    _syncNodeStateSubscription?.cancel();
    super.dispose();
  }
}
