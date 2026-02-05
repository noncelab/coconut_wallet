import 'dart:async';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/preference/home_feature.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:tuple/tuple.dart';

typedef AnimatedBalanceDataGetter = AnimatedBalanceData Function(int id);
typedef BalanceGetter = int Function(int id);
typedef FakeBalanceGetter = int? Function(int id);

const kRecenctTransactionDays = 1;

/// 기간 직접 입력(days==0) 시 범위가 없을 때 사용할 기본 분석 기간(일)
const kAnalysisPeriodFallbackDays = 30;

class WalletHomeViewModel extends ChangeNotifier {
  WalletProvider _walletProvider;
  late final PreferenceProvider _preferenceProvider;
  late final ConnectivityProvider _connectivityProvider;
  late final NodeProvider _nodeProvider;

  final Stream<NodeSyncState> _syncNodeStateStream;
  NodeSyncState _nodeSyncState = NodeSyncState.syncing;
  StreamSubscription<NodeSyncState>? _syncNodeStateSubscription;

  void _onCurrentBlockChanged() {
    // 블록이 바뀌면 tx 상태가 바뀌었을 수 있으므로 최근 tx·분석 갱신
    if (!isHomeFeatureEnabled(HomeFeatureType.analysis) && !isHomeFeatureEnabled(HomeFeatureType.recentTransaction)) {
      return;
    }
    updateWalletBalancesAndRecentTxs();
  }

  late bool _isBalanceHidden;
  late bool _isFiatBalanceHidden;
  late final bool _isReviewScreenVisible;
  // late bool? _isNetworkOn;

  Map<int, AnimatedBalanceData> _walletBalance = {};
  Map<int, dynamic> _fakeBalanceMap = {};
  int? _fakeBalanceTotalAmount;
  bool _isFirstLoaded = false;
  bool _isEmptyFavoriteWallet = false; // 즐겨찾기 설정된 지갑이 없는지 여부
  List<WalletListItemBase> _favoriteWallets = [];

  late int _analysisPeriod;
  int get analysisPeriod => _analysisPeriod;

  late AnalysisTransactionType _selectedAnalysisTransactionType;
  AnalysisTransactionType get selectedAnalysisTransactionType => _selectedAnalysisTransactionType;

  String get selectedAnalysisTransactionTypeName {
    switch (_selectedAnalysisTransactionType) {
      case AnalysisTransactionType.onlyReceived:
        return t.receive;
      case AnalysisTransactionType.onlySent:
        return t.send;
      case AnalysisTransactionType.all:
        return t.all;
    }
  }

  late List<int> _excludedFromTotalBalanceWalletIds = [];
  List<int> get excludedFromTotalBalanceWalletIds => _excludedFromTotalBalanceWalletIds;

  late WalletAddress _receiveAddress;
  bool _isFetchingLatestTx = false;
  bool get isFetchingLatestTx => _isFetchingLatestTx;

  bool _isLatestTxAnalysisRunning = false;
  bool get isLatestTxAnalysisRunning => _isLatestTxAnalysisRunning;

  bool? _prevRecentTransactionFeatureEnabled;
  bool? _prevAnalysisFeatureEnabled;

  /// recentTransaction 기능이 방금 꺼짐→켜짐으로 변경되어 초기 로딩 상태를 보여줘야 하는지 여부
  bool _showRecentFeatureInitialLoading = false;
  bool get showRecentFeatureInitialLoading => _showRecentFeatureInitialLoading;

  Map<int, List<TransactionRecord>> _recentTransactions = {};
  Map<int, List<TransactionRecord>> get recentTransactions => _recentTransactions;
  List<Tuple2<int, TransactionRecord>> get orderedRecentTransactions {
    final flatTxs =
        _recentTransactions.entries.expand((entry) => entry.value.map((tx) => Tuple2(entry.key, tx))).toList();

    final pendingStatuses = {TransactionStatus.receiving, TransactionStatus.sending, TransactionStatus.selfsending};
    final confirmedStatuses = {TransactionStatus.received, TransactionStatus.sent, TransactionStatus.self};

    final pending =
        flatTxs.where((t) => pendingStatuses.contains(TransactionUtil.getStatus(t.item2))).toList()
          ..sort((a, b) => b.item2.timestamp.compareTo(a.item2.timestamp));
    final confirmed =
        flatTxs.where((t) => confirmedStatuses.contains(TransactionUtil.getStatus(t.item2))).toList()
          ..sort((a, b) => b.item2.timestamp.compareTo(a.item2.timestamp));
    return [...pending, ...confirmed];
  }

  RecentTransactionAnalysis? _recentTransactionAnalysis;
  RecentTransactionAnalysis? get recentTransactionAnalysis => _recentTransactionAnalysis;

  bool _isBtcUnit = false;
  bool get isBtcUnit => _isBtcUnit;

  bool _isEditWidgetMode = false;
  bool get isEditWidgetMode => _isEditWidgetMode;

  void setEditWidgetMode(bool value) {
    if (_isEditWidgetMode != value) {
      _isEditWidgetMode = value;
      notifyListeners();
    }
  }

  bool isHomeFeatureEnabled(HomeFeatureType type) {
    return _preferenceProvider.isHomeFeatureEnabled(type);
  }

  WalletHomeViewModel(this._walletProvider, this._preferenceProvider, this._connectivityProvider, this._nodeProvider)
    : _syncNodeStateStream = _nodeProvider.syncStateStream {
    _isReviewScreenVisible = AppReviewService.shouldShowReviewScreen();
    _syncNodeStateSubscription = _syncNodeStateStream.listen(_handleNodeSyncState);
    _nodeProvider.currentBlockNotifier.addListener(_onCurrentBlockChanged);

    _walletBalance = _walletProvider.fetchWalletBalanceMap().map(
      (key, balance) => MapEntry(key, AnimatedBalanceData(balance.total, balance.total)),
    );
    _walletProvider.walletLoadStateNotifier.addListener(updateWalletBalancesAndRecentTxs);

    // NodeProvider의 변경사항 listening 추가
    _nodeProvider.addListener(_onNodeProviderChanged);

    _isBalanceHidden = _preferenceProvider.isBalanceHidden;
    _isFiatBalanceHidden = _preferenceProvider.isFiatBalanceHidden;
    _fakeBalanceTotalAmount = _preferenceProvider.fakeBalanceTotalAmount;
    _fakeBalanceMap = _preferenceProvider.getFakeBalanceMap();
    _excludedFromTotalBalanceWalletIds = _preferenceProvider.excludedFromTotalBalanceWalletIds;
    _analysisPeriod = _preferenceProvider.analysisPeriod;
    _selectedAnalysisTransactionType = _preferenceProvider.selectedAnalysisTransactionType;
  }

  void _onNodeProviderChanged() {
    // 블록이 생성되어 트랜잭션이 confirmed 상태로 변경되었을 수 있으므로 트랜잭션 갱신
    if (_nodeSyncState == NodeSyncState.completed) {
      updateWalletBalancesAndRecentTxs();
    }
    notifyListeners();
  }

  bool get isEmptyFavoriteWallet => _isEmptyFavoriteWallet;
  bool get isBalanceHidden => _isBalanceHidden;
  bool get isFiatBalanceHidden => _isFiatBalanceHidden;
  bool get isReviewScreenVisible => _isReviewScreenVisible;
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
  List<HomeFeature> get homeFeatures => _preferenceProvider.homeFeatures;

  bool? get isNetworkOn => _connectivityProvider.isInternetOn;
  int? get fakeBalanceTotalAmount => _fakeBalanceTotalAmount;
  Map<int, dynamic> get fakeBalanceMap => _fakeBalanceMap;
  Map<int, AnimatedBalanceData> get walletBalanceMap => _walletBalance;

  Future<void> hideHomeFeature(HomeFeatureType type) async {
    final currentFeatures = _preferenceProvider.homeFeatures;

    final updatedFeatures =
        currentFeatures
            .map(
              (feature) =>
                  feature.homeFeatureTypeString == type.name
                      ? HomeFeature(homeFeatureTypeString: feature.homeFeatureTypeString, isEnabled: false)
                      : feature,
            )
            .toList();

    await _preferenceProvider.setHomeFeautres(updatedFeatures);
    notifyListeners();
  }

  /// 네트워크 상태를 구분하여 반환
  NetworkStatus get networkStatus {
    if (_connectivityProvider.isInternetOff && _connectivityProvider.isVpnInactive) {
      return NetworkStatus.offline;
    }

    if (_nodeSyncState == NodeSyncState.completed || _nodeProvider.isInitializing) {
      return NetworkStatus.online;
    }

    if (_nodeSyncState == NodeSyncState.failed || _nodeProvider.hasConnectionError) {
      if (_connectivityProvider.isVpnActive) {
        return NetworkStatus.vpnBlocked;
      }
      return NetworkStatus.connectionFailed;
    }

    return NetworkStatus.online;
  }

  WalletListItemBase getWalletById(int walletId) {
    return _walletProvider.getWalletById(walletId);
  }

  void _handleNodeSyncState(NodeSyncState syncState) {
    Logger.log('DEBUG - _handleNodeSyncState called with: $syncState');
    if (_nodeSyncState != syncState) {
      if (syncState == NodeSyncState.completed) {
        if (!_isFirstLoaded) {
          _isFirstLoaded = true;
        }
        updateWalletBalancesAndRecentTxs();
      } else if (syncState == NodeSyncState.failed) {
        // vibrateLightDouble(); 네트워크 동기화 실패시 진동 - 제거 요청됨
      }
      _nodeSyncState = syncState;
      // Logger.log('DEBUG - _nodeSyncState updated to: $_nodeSyncState');
      notifyListeners();
    } else if (_nodeSyncState == NodeSyncState.completed && syncState == NodeSyncState.completed) {
      // 동기화가 완료된 상태에서 다시 완료 상태로 변경되면 트랜잭션 갱신
      // (트랜잭션이 confirmed 상태로 변경되었을 수 있음)
      if (_isFirstLoaded == false) {
        _isFirstLoaded = true;
      }
      _nodeSyncState = syncState;
      // 트랜잭션 동기화 완료 시 블록이 변경되었을 수 있으므로 트랜잭션 갱신
      updateWalletBalancesAndRecentTxs();
    }
  }

  Future<void> onRefresh() async {
    updateWalletBalancesAndRecentTxs();

    if (networkStatus != NetworkStatus.connectionFailed) {
      return;
    }

    _nodeProvider.reconnect();
  }

  Future<void> updateWalletBalancesAndRecentTxs() async {
    final updatedWalletBalance = _updateBalanceMap(_walletProvider.fetchWalletBalanceMap());
    _walletBalance = updatedWalletBalance;

    // 최근 트랜잭션: 동기화 완료+블록 높이 있으면 forceRefresh, 아니어도 DB(날짜 기준)로 갱신
    final shouldForceRefresh =
        _nodeSyncState == NodeSyncState.completed && _walletProvider.currentBlockHeightNotifier.value?.height != null;
    refreshRecentTxList(kRecenctTransactionDays, forceRefresh: shouldForceRefresh);

    updateRecentTxAnalysis(_analysisPeriod);
    notifyListeners();
  }

  Map<int, AnimatedBalanceData> _updateBalanceMap(Map<int, Balance> balanceMap) {
    return balanceMap.map((key, balance) {
      final prev = _walletBalance[key]?.current ?? 0;
      return MapEntry(key, AnimatedBalanceData(balance.total, prev));
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

    /// 법정화폐잔액숨기기 변동 체크
    if (_isFiatBalanceHidden != _preferenceProvider.isFiatBalanceHidden) {
      setIsFiatBalanceHidden(_preferenceProvider.isFiatBalanceHidden);
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
    if (_favoriteWallets.map((w) => w.id).toList().toString() != _preferenceProvider.favoriteWalletIds.toString() &&
        walletItemList.isNotEmpty) {
      loadFavoriteWallets();
    }

    /// 홈 기능 설정(HomeFeatures) 변동 체크
    // HomeFeatureProvider가 직접 관리하므로 별도 로드 불필요

    /// 총 잔액에서 제외할 지갑 목록 변경 체크
    if (!const SetEquality().equals(
      _excludedFromTotalBalanceWalletIds.toSet(),
      _preferenceProvider.excludedFromTotalBalanceWalletIds.toSet(),
    )) {
      _excludedFromTotalBalanceWalletIds = _preferenceProvider.excludedFromTotalBalanceWalletIds;
    }

    if (_analysisPeriod != _preferenceProvider.analysisPeriod) {
      _analysisPeriod = _preferenceProvider.analysisPeriod;
    }

    if (_preferenceProvider.isBtcUnit != _isBtcUnit) {
      _isBtcUnit = _preferenceProvider.isBtcUnit;
      updateRecentTxAnalysis(_analysisPeriod);
    }
    notifyListeners();
  }

  void setIsBalanceHidden(bool value) {
    _preferenceProvider.changeIsBalanceHidden(value);
    _isBalanceHidden = value;
    notifyListeners();
  }

  void setIsFiatBalanceHidden(bool value) {
    _preferenceProvider.changeIsFiatBalanceHidden(value);
    _isFiatBalanceHidden = value;
    notifyListeners();
  }

  void _setFakeBlancTotalAmount(int? value) {
    _fakeBalanceTotalAmount = value;
    notifyListeners();
  }

  void clearFakeBlanceTotalAmount() {
    _preferenceProvider.clearFakeBalanceTotalAmount();
    _preferenceProvider.toggleFakeBalanceActivation(false); // 가짜잔액 초기화시 비활성화도 같이 수행(Wallet_home 에서만)
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

  int getHomeFakeBalanceTotal() {
    if (_fakeBalanceTotalAmount == null) return 0;

    int totalAmount = 0;

    // excludedFromTotalBalanceWalletIds에 포함되지 않은 지갑들의 가짜 잔액을 더함
    for (final wallet in walletItemList) {
      if (!_excludedFromTotalBalanceWalletIds.contains(wallet.id)) {
        final fakeBalance = _fakeBalanceMap[wallet.id];
        if (fakeBalance != null && fakeBalance is num) {
          totalAmount += fakeBalance.toInt();
        }
      }
    }

    return totalAmount;
  }

  void onNodeProviderUpdated() {
    notifyListeners();
  }

  bool isWalletListChanged(
    List<WalletListItemBase> oldList,
    List<WalletListItemBase> newList,
    Map<int, AnimatedBalanceData> walletBalanceMap,
  ) {
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

    final wallets =
        ids
            .map((id) => _walletProvider.walletItemListNotifier.value.firstWhereOrNull((w) => w.id == id))
            .whereType<WalletListItemBase>()
            .toList();

    _favoriteWallets = wallets;

    _isEmptyFavoriteWallet = wallets.isEmpty;

    notifyListeners();
  }

  void setReceiveAddress(int walletId) {
    _receiveAddress = _walletProvider.getReceiveAddress(walletId);
    Logger.log('--> 리시브주소: ${_receiveAddress.address}');
  }

  void refreshRecentTxList(int days, {bool forceRefresh = false}) {
    if (!forceRefresh && _isFetchingLatestTx) return;

    // 최근 트랜잭션 홈 기능이 비활성화된 경우에는 조회하지 않음
    if (!isHomeFeatureEnabled(HomeFeatureType.recentTransaction)) return;
    _isFetchingLatestTx = true;

    // 홈 화면에 표시한 지갑 목록 아이디
    final walletIds = walletItemList.map((w) => w.id).toList();
    final transactions = _walletProvider.getPendingAndDaysAgoTransactions(walletIds, days);
    _recentTransactions = transactions;

    // recentTransactions 로그 출력
    for (var entry in _recentTransactions.entries) {
      Logger.log('WalletHomeViewModel: 지갑 ID ${entry.key} - 트랜잭션 개수: ${entry.value.length}');
      // 개별 트랜잭션의 해시와 value 출력
      for (var tx in entry.value) {
        Logger.log(
          '\tTxHash: ${tx.transactionHash}, Type: ${tx.transactionType.name}, Amount: ${tx.amount}, Status: ${TransactionUtil.getStatus(tx)}',
        );
      }
    }

    _isFetchingLatestTx = false;
    // 트랜잭션 목록이 갱신 후 분석 기능이 활성화되어 있으면 분석 데이터도 함께 갱신
    if (isHomeFeatureEnabled(HomeFeatureType.analysis)) updateRecentTxAnalysis(_analysisPeriod);

    notifyListeners();
  }

  // 필요한 경우 호출
  void updateRecentTxAnalysis(int days) {
    // 분석 기능이 비활성화된 경우에는 조회하지 않음
    if (!isHomeFeatureEnabled(HomeFeatureType.analysis)) {
      _isLatestTxAnalysisRunning = false;
      return;
    }

    _isLatestTxAnalysisRunning = true;
    final walletIds = walletItemList.map((w) => w.id).toList();

    // 날짜 범위 계산 (DB의 timestamp 기준)
    // days==0(기간 직접 입력)이고, 범위가 없는 경우 기본 기간 사용
    final bool useCustomRange =
        _analysisPeriod == 0 &&
        _preferenceProvider.analysisPeriodRange.item1 != null &&
        _preferenceProvider.analysisPeriodRange.item2 != null;
    final effectiveDays = useCustomRange ? 0 : (days > 0 ? days : kAnalysisPeriodFallbackDays);
    final DateTime startDate;
    final DateTime endDate;
    if (useCustomRange) {
      // 사용자가 사용하는 시간대로 00:00:00 ~ 23:59:59.999 로 변환
      final start = _preferenceProvider.analysisPeriodRange.item1!;
      final end = _preferenceProvider.analysisPeriodRange.item2!;
      startDate = DateTime(start.year, start.month, start.day, 0, 0, 0, 0);
      endDate = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    } else {
      startDate = DateTime.now().subtract(Duration(days: effectiveDays));
      endDate = DateTime.now();
    }

    // DB의 timestamp로 직접 조회
    final transactions = _walletProvider.getConfirmedTransactionRecordListWithinDateRange(
      walletIds,
      Tuple2<DateTime, DateTime>(startDate, endDate),
    );

    final receivedTxs = transactions.where((t) => t.transactionType == TransactionType.received).toList();
    final sentTxs = transactions.where((t) => t.transactionType == TransactionType.sent).toList();
    final selfTxs = transactions.where((t) => t.transactionType == TransactionType.self).toList();

    final receivedAmount = receivedTxs.fold(0, (sum, t) => sum + t.amount);
    final sentAmount = sentTxs.fold(0, (sum, t) => sum + t.amount);
    final selfAmount = selfTxs.fold(0, (sum, t) => sum + t.amount);

    final totalAmount = receivedAmount + sentAmount + selfAmount;

    final daysForAnalysis = useCustomRange ? 0 : effectiveDays;

    _recentTransactionAnalysis = RecentTransactionAnalysis(
      startDate: startDate,
      endDate: endDate,
      receivedTxs: receivedTxs,
      sentTxs: sentTxs,
      selfTxs: selfTxs,
      totalAmount: totalAmount,
      receivedAmount: receivedAmount,
      sentAmount: sentAmount,
      selfAmount: selfAmount,
      days: daysForAnalysis,
      isBtcUnit: _isBtcUnit,
      selectedAnalysisTransactionType: _selectedAnalysisTransactionType,
    );
    _isLatestTxAnalysisRunning = false;
    notifyListeners();
  }

  void updateAnalysisPeriod(int value) {
    _analysisPeriod = value;
    _preferenceProvider.setAnalysisPeriod(value);
    updateRecentTxAnalysis(value);
    notifyListeners();
  }

  void setAnalysisTransactionType(AnalysisTransactionType value) {
    _selectedAnalysisTransactionType = value;
    _preferenceProvider.setAnalysisTransactionType(value);

    updateRecentTxAnalysis(_analysisPeriod);
    notifyListeners();
  }

  /// 홈 편집 바텀시트를 열기 직전, 현재 홈 기능 활성화 상태를 스냅샷으로 저장
  void captureEnabledFeaturesSnapshot() {
    _prevRecentTransactionFeatureEnabled = isHomeFeatureEnabled(HomeFeatureType.recentTransaction);
    _prevAnalysisFeatureEnabled = isHomeFeatureEnabled(HomeFeatureType.analysis);
  }

  void refreshEnabledFeaturesData() {
    final bool showRecentTxWidget = isHomeFeatureEnabled(HomeFeatureType.recentTransaction);
    final bool showTxAnalysisWidget = isHomeFeatureEnabled(HomeFeatureType.analysis);

    // recentTransaction 기능이 false → true 로 바뀐 경우, 초기 로딩 상태 활성화(2초 동안만)
    final bool recentJustEnabled = (_prevRecentTransactionFeatureEnabled == false) && showRecentTxWidget;
    if (recentJustEnabled) {
      _showRecentFeatureInitialLoading = true;
      notifyListeners();
      // 2초 동안만 초기 로딩 상태(true) 유지 후 자동으로 false로 변경
      Future.delayed(const Duration(seconds: 2), () {
        if (_showRecentFeatureInitialLoading) {
          _showRecentFeatureInitialLoading = false;
          notifyListeners();
        }
      });
    }

    if (showRecentTxWidget != _prevRecentTransactionFeatureEnabled) {
      if (showRecentTxWidget) {
        refreshRecentTxList(kRecenctTransactionDays);
      }
      _prevRecentTransactionFeatureEnabled = showRecentTxWidget;
    }

    if (showTxAnalysisWidget != _prevAnalysisFeatureEnabled) {
      if (showTxAnalysisWidget) {
        updateRecentTxAnalysis(_analysisPeriod);
      }
      _prevAnalysisFeatureEnabled = showTxAnalysisWidget;
    }
  }

  @override
  void dispose() {
    _syncNodeStateSubscription?.cancel();
    _nodeProvider.removeListener(_onNodeProviderChanged);
    _nodeProvider.currentBlockNotifier.removeListener(_onCurrentBlockChanged);
    super.dispose();
  }
}

class RecentTransactionAnalysis {
  final int totalAmount;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<TransactionRecord> receivedTxs;
  final List<TransactionRecord> sentTxs;
  final List<TransactionRecord> selfTxs;
  final int receivedAmount;
  final int sentAmount;
  final int selfAmount;
  final int days;
  final bool isBtcUnit;
  final AnalysisTransactionType selectedAnalysisTransactionType;

  const RecentTransactionAnalysis({
    required this.totalAmount,
    required this.startDate,
    required this.endDate,
    required this.receivedTxs,
    required this.sentTxs,
    required this.selfTxs,
    required this.receivedAmount,
    required this.sentAmount,
    required this.selfAmount,
    required this.days,
    required this.isBtcUnit,
    required this.selectedAnalysisTransactionType,
  });

  bool get isEmpty =>
      receivedTxs.isEmpty &&
      sentTxs.isEmpty &&
      selfTxs.isEmpty &&
      receivedAmount == 0 &&
      sentAmount == 0 &&
      selfAmount == 0;

  int get totalTransactionCount => receivedTxs.length + sentTxs.length + selfTxs.length;
  String get totalTransactionResult =>
      selectedAnalysisTransactionType == AnalysisTransactionType.onlyReceived
          ? t.wallet_home_screen.received
          : selectedAnalysisTransactionType == AnalysisTransactionType.onlySent
          ? t.wallet_home_screen.sent
          : totalAmount > 0
          ? t.wallet_home_screen.increase
          : t.wallet_home_screen.decrease;
  String get dateRange => '$_startDate ~ $_endDate';
  String get _startDate =>
      days == 0
          ? _formatYyMmDd(startDate ?? DateTime.now())
          : _formatYyMmDd(DateTime.now().subtract(Duration(days: days)));

  String get _endDate => days == 0 ? _formatYyMmDd(endDate ?? DateTime.now()) : _formatYyMmDd(DateTime.now());

  String get titleString =>
      '${isBtcUnit ? BitcoinUnit.btc.displayBitcoinAmount(selectedAnalysisTransactionType == AnalysisTransactionType.onlyReceived
              ? receivedAmount
              : selectedAnalysisTransactionType == AnalysisTransactionType.onlySent
              ? (sentAmount + selfAmount).abs()
              : totalAmount.abs(), withUnit: true) : BitcoinUnit.sats.displayBitcoinAmount(selectedAnalysisTransactionType == AnalysisTransactionType.onlyReceived
              ? receivedAmount
              : selectedAnalysisTransactionType == AnalysisTransactionType.onlySent
              ? sentAmount + selfAmount
              : totalAmount.abs(), withUnit: true)} ';
  String get totalAmountResult => totalTransactionResult;
  String get subtitleString =>
      '$dateRange | ${t.wallet_home_screen.transaction_count(count: selectedAnalysisTransactionType == AnalysisTransactionType.onlyReceived
          ? receivedTxs.length.toString()
          : selectedAnalysisTransactionType == AnalysisTransactionType.onlySent
          ? (sentTxs.length + selfTxs.length).toString()
          : totalTransactionCount.toString())}';

  /// 사용자가 지정한 날짜대로 표시하기 위해 UTC 날짜 기준 포맷.
  String _formatYyMmDd(DateTime dt) {
    final y = dt.year % 100;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final yy = y.toString().padLeft(2, '0');
    return '$yy.$m.$d';
  }
}

enum AnalysisTransactionType { onlySent, onlyReceived, all }
