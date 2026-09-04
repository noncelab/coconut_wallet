import 'dart:async';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/price/historical_bitcoin_prices.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_balance_history_point.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/historical_bitcoin_price_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/constants/app_language.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

typedef AnimatedBalanceDataGetter = AnimatedBalanceData Function(int id);
typedef BalanceGetter = int Function(int id);
typedef FakeBalanceGetter = int? Function(int id);

class WalletListViewModel extends ChangeNotifier {
  final ValueNotifier<bool> loadingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> pinCheckNotifier = ValueNotifier(false);
  final SharedPrefsRepository sharedPrefs = SharedPrefsRepository();

  WalletProvider _walletProvider;
  late final ConnectivityProvider _connectivityProvider;
  late final AuthProvider _authProvider;
  late final NodeProvider _nodeProvider;
  late final PriceProvider _priceProvider;
  final HistoricalBitcoinPriceService _historicalBitcoinPriceService;
  late Stream<NodeSyncState> _syncNodeStateStream;
  late PreferenceProvider _preferenceProvider;
  late bool? _isNetworkOn;
  Map<int, AnimatedBalanceData> _walletBalance = {};
  late List<WalletItemBase> _walletItemListSnapshot;

  bool _isFirstLoaded = false;
  NodeSyncState _nodeSyncState = NodeSyncState.syncing;
  StreamSubscription<NodeSyncState>? _syncNodeStateSubscription;
  bool _isDisposed = false;

  // late final StreamSubscription _preferenceSubscription;
  late List<int> _walletOrder = [];
  List<int> get walletOrder => _walletOrder;
  // 임시 지갑 순서 ID 목록(편집용)
  List<int> tempWalletOrder = [];

  late List<int> _favoriteWalletIds = [];
  List<int> get favoriteWalletIds => _favoriteWalletIds;

  late List<int> _excludedFromTotalBalanceWalletIds = [];
  List<int> get excludedFromTotalBalanceWalletIds => _excludedFromTotalBalanceWalletIds;

  bool _isEditMode = false;
  bool get isEditMode => _isEditMode;

  HistoricalBitcoinPrices? _historicalBitcoinPrices;
  HistoricalBitcoinPrices? get historicalBitcoinPrices => _historicalBitcoinPrices;
  bool _isHistoricalBitcoinPricesLoading = false;
  bool get isHistoricalBitcoinPricesLoading => _isHistoricalBitcoinPricesLoading;
  bool get supportsHistoricalBitcoinPrices => selectedFiat != FiatCode.JPY;
  FiatCode? _historicalBitcoinPriceFiat;

  bool get hasEnglishWordOrder => AppLanguage.fromCode(_preferenceProvider.language).hasEnglishWordOrder;

  bool get isWalletListFiatVisible => _preferenceProvider.isWalletListFiatVisible;
  bool get isWalletListBitcoinPriceVisible => _preferenceProvider.isWalletListBitcoinPriceVisible;
  bool get isWalletListBalanceChartVisible => _preferenceProvider.isWalletListBalanceChartVisible;

  List<WalletBalanceHistoryPoint> _walletBalanceHistory = const [];
  List<WalletBalanceHistoryPoint> get walletBalanceHistory => _walletBalanceHistory;
  int _walletBalanceHistoryRevision = 0;
  int get walletBalanceHistoryRevision => _walletBalanceHistoryRevision;

  late List<FiatCode> _visibleFiats;
  List<FiatCode> get visibleFiats => _visibleFiats;

  List<FiatCode> get orderedFiats => _preferenceProvider.orderedFiats;
  FiatCode get selectedFiat => _preferenceProvider.selectedFiat;

  WalletListViewModel(
    this._walletProvider,
    this._connectivityProvider,
    this._authProvider,
    this._nodeProvider,
    this._preferenceProvider,
    this._priceProvider, {
    HistoricalBitcoinPriceService? historicalBitcoinPriceService,
  }) : _historicalBitcoinPriceService = historicalBitcoinPriceService ?? HistoricalBitcoinPriceService() {
    _isNetworkOn = _connectivityProvider.isInternetOn;
    _walletOrder = _preferenceProvider.walletOrder;
    _favoriteWalletIds = _preferenceProvider.favoriteWalletIds;
    _excludedFromTotalBalanceWalletIds = _preferenceProvider.excludedFromTotalBalanceWalletIds;
    _visibleFiats = _preferenceProvider.walletListVisibleFiats;
    _syncNodeStateStream = _nodeProvider.syncStateStream;
    _syncNodeStateSubscription = _syncNodeStateStream.listen(_handleNodeSyncState);
    _walletItemListSnapshot = List<WalletItemBase>.from(_walletProvider.walletItemList);
    _walletBalance = _walletProvider.fetchWalletBalanceMap().map(
      (key, balance) => MapEntry(key, AnimatedBalanceData(balance.total, balance.total)),
    );
    _updateWalletBalanceHistory();
    _walletProvider.walletLoadStateNotifier.addListener(updateWalletBalances);
    _preferenceProvider.addListener(_onPreferenceChanged);
    _priceProvider.addListener(_updateBitcoinPrice);
    unawaited(loadHistoricalBitcoinPrices());
  }

  void _updateBitcoinPrice() {
    notifyListeners();
  }

  String getBitcoinPrice(int satoshiAmount, FiatCode fiatCode) {
    return _priceProvider.getFiatPrice(satoshiAmount, fiatCode: fiatCode);
  }

  int? get currentSelectedFiatBitcoinPrice => _priceProvider.getBitcoinPriceForFiat(selectedFiat);

  void _onPreferenceChanged() {
    onPreferenceProviderUpdated();
    if (_historicalBitcoinPriceFiat != selectedFiat) {
      unawaited(loadHistoricalBitcoinPrices());
    }
  }

  Future<void> loadHistoricalBitcoinPrices() async {
    if (_isDisposed) return;
    final fiatCode = selectedFiat;
    _historicalBitcoinPriceFiat = fiatCode;
    _historicalBitcoinPrices = null;

    if (fiatCode == FiatCode.JPY) {
      _isHistoricalBitcoinPricesLoading = false;
      notifyListeners();
      return;
    }

    _isHistoricalBitcoinPricesLoading = true;
    notifyListeners();
    try {
      final prices = await _historicalBitcoinPriceService.fetch(fiatCode);
      if (_isDisposed || _historicalBitcoinPriceFiat != fiatCode) return;
      _historicalBitcoinPrices = prices;
    } catch (e) {
      if (_isDisposed || _historicalBitcoinPriceFiat != fiatCode) return;
      Logger.error('과거 BTC 종가 조회 실패 ($fiatCode): $e');
      _historicalBitcoinPrices = null;
    } finally {
      if (!_isDisposed && _historicalBitcoinPriceFiat == fiatCode) {
        _isHistoricalBitcoinPricesLoading = false;
        notifyListeners();
      }
    }
  }

  bool get shouldShowLoadingIndicator => !_isFirstLoaded && _nodeSyncState == NodeSyncState.syncing;
  List<WalletItemBase> get walletItemList {
    final walletList = _walletProvider.walletItemListNotifier.value;
    final order = _preferenceProvider.walletOrder;

    if (order.isEmpty) {
      return walletList;
    }

    final walletMap = {for (var wallet in walletList) wallet.id: wallet};
    var orderedMap = order.map((id) => walletMap[id]).whereType<WalletItemBase>().toList();
    return orderedMap;
  }

  bool? get isNetworkOn => _isNetworkOn;
  Map<int, AnimatedBalanceData> get walletBalanceMap => _walletBalance;

  void _handleNodeSyncState(NodeSyncState syncState) {
    if (_nodeSyncState != syncState) {
      if (syncState == NodeSyncState.completed) {
        if (!_isFirstLoaded) {
          _isFirstLoaded = true;
        }
        updateWalletBalances();
      } else if (syncState == NodeSyncState.failed) {
        if (!_nodeProvider.isServerChanging && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
          vibrateLightDouble();
        }
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

  void setEditMode(bool isEditMode) {
    _isEditMode = isEditMode;
    if (isEditMode) {
      tempWalletOrder = walletItemList.map((w) => w.id).toList();
    }
    notifyListeners();
  }

  void onPreferenceProviderUpdated() {
    var didChange = false;

    if (!const ListEquality().equals(_favoriteWalletIds, _preferenceProvider.favoriteWalletIds)) {
      _favoriteWalletIds = List.from(_preferenceProvider.favoriteWalletIds);
      didChange = true;
    }

    /// 지갑 순서 변경 체크
    if (!const ListEquality().equals(_walletOrder, _preferenceProvider.walletOrder)) {
      _walletOrder = _preferenceProvider.walletOrder;
      didChange = true;
    }

    /// 총 잔액에서 제외할 지갑 목록 변경 체크
    if (!const SetEquality().equals(
      _excludedFromTotalBalanceWalletIds.toSet(),
      _preferenceProvider.excludedFromTotalBalanceWalletIds.toSet(),
    )) {
      _excludedFromTotalBalanceWalletIds = _preferenceProvider.excludedFromTotalBalanceWalletIds;
      didChange = true;
    }

    /// 보여지는 통화 목록 변경 체크
    if (!const ListEquality().equals(_visibleFiats, _preferenceProvider.walletListVisibleFiats)) {
      _visibleFiats = _preferenceProvider.walletListVisibleFiats;
      didChange = true;
    }

    if (didChange) {
      notifyListeners();
    }
  }

  Future<void> updateWalletBalances() async {
    if (_isDisposed) return;
    final updatedWalletBalance = _updateBalanceMap(_walletProvider.fetchWalletBalanceMap());
    _walletBalance = updatedWalletBalance;
    _updateWalletBalanceHistory();
    notifyListeners();
  }

  void _updateWalletBalanceHistory() {
    final transactions =
        _walletProvider.walletItemList.expand((wallet) => _walletProvider.getTransactionRecordList(wallet.id)).toList()
          ..sort((a, b) {
            final timestampComparison = a.timestamp.compareTo(b.timestamp);
            if (timestampComparison != 0) return timestampComparison;
            return a.createdAt.compareTo(b.createdAt);
          });

    final updatedHistory = <WalletBalanceHistoryPoint>[];
    var runningBalance = 0;
    if (transactions.isNotEmpty) {
      updatedHistory.add(
        WalletBalanceHistoryPoint(
          timestamp: transactions.first.timestamp.subtract(const Duration(seconds: 1)),
          balance: 0,
        ),
      );
    }
    for (final transaction in transactions) {
      runningBalance += transaction.amount;
      updatedHistory.add(WalletBalanceHistoryPoint(timestamp: transaction.timestamp, balance: runningBalance));
    }

    final currentBalance = _walletBalance.values.fold<int>(0, (sum, balance) => sum + balance.current);
    if (updatedHistory.isEmpty) {
      updatedHistory.addAll([
        WalletBalanceHistoryPoint(timestamp: DateTime.fromMillisecondsSinceEpoch(0), balance: currentBalance),
        WalletBalanceHistoryPoint(timestamp: DateTime.fromMillisecondsSinceEpoch(1), balance: currentBalance),
      ]);
    } else if (updatedHistory.last.balance != currentBalance) {
      updatedHistory.add(
        WalletBalanceHistoryPoint(
          timestamp: updatedHistory.last.timestamp.add(const Duration(seconds: 1)),
          balance: currentBalance,
        ),
      );
    }

    final sampledHistory = _sampleBalanceHistory(updatedHistory);
    final hasChanged =
        sampledHistory.length != _walletBalanceHistory.length ||
        List.generate(sampledHistory.length, (index) {
          if (index >= _walletBalanceHistory.length) return true;
          final previous = _walletBalanceHistory[index];
          final current = sampledHistory[index];
          return previous.timestamp != current.timestamp || previous.balance != current.balance;
        }).any((isDifferent) => isDifferent);
    if (!hasChanged) return;

    _walletBalanceHistory = sampledHistory;
    _walletBalanceHistoryRevision++;
  }

  List<WalletBalanceHistoryPoint> _sampleBalanceHistory(List<WalletBalanceHistoryPoint> history) {
    const maximumPointCount = 120;
    if (history.length <= maximumPointCount) return history;

    final interval = (history.length / maximumPointCount).ceil();
    final sampled = <WalletBalanceHistoryPoint>[
      for (var index = 0; index < history.length; index += interval) history[index],
    ];
    if (sampled.last != history.last) {
      sampled.add(history.last);
    }
    return sampled;
  }

  Map<int, AnimatedBalanceData> _updateBalanceMap(Map<int, Balance> balanceMap) {
    return balanceMap.map((key, balance) {
      final prev = _walletBalance[key]?.current ?? 0;
      return MapEntry(key, AnimatedBalanceData(balance.total, prev));
    });
  }

  void onWalletProviderUpdated(WalletProvider walletProvider) {
    final didProviderChange = !identical(_walletProvider, walletProvider);
    _walletProvider = walletProvider;

    if (_updateWalletItemListSnapshot() || didProviderChange) {
      _updateWalletBalanceHistory();
      notifyListeners();
    }
  }

  void onNodeProviderUpdated() {
    notifyListeners();
  }

  void updateIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  bool isWalletListChanged(
    List<WalletItemBase> oldList,
    List<WalletItemBase> newList,
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

  Future<void> toggleFavorite(int walletId) async {
    final updatedFavoriteWalletIds = List<int>.from(_favoriteWalletIds);
    if (updatedFavoriteWalletIds.contains(walletId)) {
      updatedFavoriteWalletIds.remove(walletId);
    } else {
      if (updatedFavoriteWalletIds.length >= 5) return;
      updatedFavoriteWalletIds.add(walletId);
    }

    _favoriteWalletIds = updatedFavoriteWalletIds;
    notifyListeners();
    await _preferenceProvider.setFavoriteWalletIds(updatedFavoriteWalletIds);
  }

  void clearTempDatas() {
    tempWalletOrder.clear();
    notifyListeners();
  }

  /// 임시값을 실제 walletList에 반영
  Future<void> applyTempDatasToWallets() async {
    if (!hasWalletOrderChanged) return;

    final deletedWalletIds = _preferenceProvider.walletOrder.where((id) => !tempWalletOrder.contains(id)).toList();
    await _handleAuthFlow(
      onComplete: () async {
        if (hasWalletOrderChanged) {
          // 삭제 여부 판단
          if (tempWalletOrder.length != _preferenceProvider.walletOrder.length) {
            setLoadingNotifier(true);

            await _deleteWallets(deletedWalletIds);
            setLoadingNotifier(false);
          }
          await _preferenceProvider.setWalletOrder(tempWalletOrder);

          final walletMap = {for (var wallet in walletItemList) wallet.id: wallet};
          _walletProvider.walletItemListNotifier.value =
              tempWalletOrder.map((id) => walletMap[id]).whereType<WalletItemBase>().toList();
        }
        setEditMode(false);
        notifyListeners();
      },
      hasWalletDeleted: deletedWalletIds.isNotEmpty,
    );
  }

  VoidCallback? _pendingAuthCompleteCallback;

  Future<void> _handleAuthFlow({required VoidCallback onComplete, required bool hasWalletDeleted}) async {
    if (!hasWalletDeleted) {
      // 지갑이 삭제된 경우가 아니라면 pinCheck 생략
      onComplete();
      return;
    }
    if (!_authProvider.isAuthEnabled) {
      onComplete();
      return;
    }

    if (await _authProvider.isBiometricsAuthValid()) {
      onComplete();
      return;
    }

    _pendingAuthCompleteCallback = onComplete;
    setPincheckNotifier(true);
    notifyListeners();
  }

  void handleAuthCompletion() {
    if (_pendingAuthCompleteCallback != null) {
      _pendingAuthCompleteCallback!();
      _pendingAuthCompleteCallback = null;
    }
  }

  Future<void> _deleteWallets(List<int> deletedWalletIds) async {
    for (int i = 0; i < deletedWalletIds.length; i++) {
      int walletId = deletedWalletIds[i];
      await sharedPrefs.removeFaucetHistory(walletId);
      await sharedPrefs.removeWalletTargetSats(walletId);
      await _walletProvider.deleteWallet(walletId);
    }
    _nodeProvider.reconnect();
    _walletProvider.notifyListeners();
  }

  bool get hasWalletOrderChanged => !const ListEquality().equals(tempWalletOrder, _preferenceProvider.walletOrder);

  void reorderTempWalletOrder(int oldIndex, int newIndex) {
    final item = tempWalletOrder.removeAt(oldIndex);
    tempWalletOrder.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    notifyListeners();
  }

  void removeTempWalletOrderByWalletId(int walletId) async {
    final orderIndex = tempWalletOrder.indexOf(walletId);
    if (orderIndex != -1) {
      tempWalletOrder.removeAt(orderIndex);
    }
    notifyListeners();
  }

  void updatePreferenceProvider(PreferenceProvider preferenceProvider) {
    if (_preferenceProvider != preferenceProvider) {
      _preferenceProvider.removeListener(_onPreferenceChanged);
      _preferenceProvider = preferenceProvider;
      _preferenceProvider.addListener(_onPreferenceChanged);
      onPreferenceProviderUpdated();
    }
  }

  void setLoadingNotifier(bool value) {
    loadingNotifier.value = value;
  }

  void setPincheckNotifier(bool value) {
    pinCheckNotifier.value = value;
  }

  void setVisibleFiats(List<FiatCode> fiats) {
    if (const ListEquality().equals(_visibleFiats, fiats)) {
      return;
    }

    _preferenceProvider.setWalletListVisibleFiats(fiats);
    _visibleFiats = _preferenceProvider.walletListVisibleFiats;
    notifyListeners();
  }

  void toggleWalletListFiatVisible() {
    _preferenceProvider.setWalletListFiatVisible(!_preferenceProvider.isWalletListFiatVisible);
    notifyListeners();
  }

  void setWalletListFiatVisible(bool isVisible) {
    if (_preferenceProvider.isWalletListFiatVisible == isVisible) {
      return;
    }

    _preferenceProvider.setWalletListFiatVisible(isVisible);
    notifyListeners();
  }

  void setWalletListBitcoinPriceVisible(bool isVisible) {
    if (_preferenceProvider.isWalletListBitcoinPriceVisible == isVisible) {
      return;
    }

    _preferenceProvider.setWalletListBitcoinPriceVisible(isVisible);
    notifyListeners();
  }

  void setWalletListBalanceChartVisible(bool isVisible) {
    if (_preferenceProvider.isWalletListBalanceChartVisible == isVisible) {
      return;
    }

    _preferenceProvider.setWalletListBalanceChartVisible(isVisible);
    notifyListeners();
  }

  bool _updateWalletItemListSnapshot() {
    final walletItemList = _walletProvider.walletItemList;
    if (_isSameWalletItemList(_walletItemListSnapshot, walletItemList)) {
      return false;
    }

    _walletItemListSnapshot = List<WalletItemBase>.from(walletItemList);
    return true;
  }

  bool _isSameWalletItemList(List<WalletItemBase> previous, List<WalletItemBase> current) {
    if (previous.length != current.length) {
      return false;
    }

    for (var i = 0; i < previous.length; i++) {
      if (previous[i].toString() != current[i].toString()) {
        return false;
      }
    }

    return true;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _syncNodeStateSubscription?.cancel();
    _walletProvider.walletLoadStateNotifier.removeListener(updateWalletBalances);
    _preferenceProvider.removeListener(_onPreferenceChanged);
    _priceProvider.removeListener(_updateBitcoinPrice);
    loadingNotifier.dispose();
    pinCheckNotifier.dispose();
    super.dispose();
  }
}
