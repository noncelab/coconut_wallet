import 'dart:async';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/historical_bitcoin_price_service.dart';
import 'package:coconut_wallet/services/home/home_widget_math.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/utils/utxo_tier_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:tuple/tuple.dart';

/// 새 홈의 위젯들이 함께 쓰는 데이터
/// 가짜 잔액이 켜져 있으면 금액이 드러나는 값은 모두 가짜로 반환
class HomeWidgetsViewModel extends ChangeNotifier {
  static const defaultDays = 7;

  final WalletProvider _walletProvider;
  final PreferenceProvider _preferenceProvider;
  final PriceProvider _priceProvider;
  final HistoricalBitcoinPriceService _historicalPriceService;
  final int? Function(int walletId) _targetSatsOf;
  final DateTime Function() _now;
  final Listenable? _walletUpdates;

  final Map<FiatCode, List<double>?> _dailyCloses = {};
  final Set<FiatCode> _loadingCloses = {};
  static const priceWaitLimit = Duration(seconds: 10);

  final Map<String, Object?> _cache = {};
  bool _disposed = false;
  bool _priceWaitExpired = false;
  Timer? _priceWaitTimer;

  HomeWidgetsViewModel({
    required WalletProvider walletProvider,
    required PreferenceProvider preferenceProvider,
    required PriceProvider priceProvider,
    required int? Function(int walletId) targetSatsOf,
    HistoricalBitcoinPriceService? historicalPriceService,
    DateTime Function()? now,
    Listenable? walletUpdates,
    this.usesFakeBalance = true,
  }) : _walletProvider = walletProvider,
       _walletUpdates = walletUpdates,
       _preferenceProvider = preferenceProvider,
       _priceProvider = priceProvider,
       _targetSatsOf = targetSatsOf,
       _historicalPriceService = historicalPriceService ?? HistoricalBitcoinPriceService(),
       _now = now ?? DateTime.now {
    _walletProvider.walletLoadStateNotifier.addListener(_onDataChanged);
    _walletProvider.walletItemListNotifier.addListener(_onDataChanged);
    _preferenceProvider.addListener(_onDataChanged);
    _walletUpdates?.addListener(_onDataChanged);
    _priceProvider.addListener(notifyListeners);
    _priceWaitTimer = Timer(priceWaitLimit, () {
      _priceWaitExpired = true;
      if (!_disposed) notifyListeners();
    });
  }

  bool get isWalletDataLoading => _walletProvider.walletLoadState != WalletLoadState.loadCompleted;

  /// 시세를 아직 못 받았으면 잠깐 기다리는 중으로 본다.
  /// 오래 오지 않으면(오프라인 등) 기다리지 않고 값 없음으로 보여 준다.
  bool isPriceLoading(FiatCode fiatCode) => priceOf(fiatCode) == null && !_priceWaitExpired;

  bool isDailyClosesLoading(FiatCode fiatCode) {
    _closesOf(fiatCode);
    return _loadingCloses.contains(fiatCode);
  }

  void _onDataChanged() {
    _cache.clear();
    notifyListeners();
  }

  /// 지갑 목표처럼 이 뷰모델이 듣지 않는 저장값이 바뀌었을 때 다시 그린다.
  void refresh() => _onDataChanged();

  T _cached<T>(String key, T Function() compute) => _cache.putIfAbsent(key, compute) as T;

  BitcoinUnit get unit => _preferenceProvider.currentUnit;
  FiatCode get fiat => _preferenceProvider.selectedFiat;
  bool get isFakeBalance => usesFakeBalance && _preferenceProvider.isFakeBalanceActive;

  /// 가짜 잔액은 홈에만 쓴다. 홈 밖(지갑 목록, 상세, 호들 인사이트 등)에서는 이 사본으로 실제 값을 본다.
  final bool usesFakeBalance;

  HomeWidgetsViewModel withoutFakeBalance() => HomeWidgetsViewModel(
    walletProvider: _walletProvider,
    preferenceProvider: _preferenceProvider,
    priceProvider: _priceProvider,
    targetSatsOf: _targetSatsOf,
    historicalPriceService: _historicalPriceService,
    now: _now,
    walletUpdates: _walletUpdates,
    usesFakeBalance: false,
  );

  List<WalletItemBase> get wallets => _cached('wallets', () {
    final order = _preferenceProvider.walletOrder;
    final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
    final list = [..._walletProvider.walletItemList];
    final original = {for (var i = 0; i < list.length; i++) list[i].id: i};
    list.sort(
      (a, b) => (rank[a.id] ?? order.length + original[a.id]!).compareTo(rank[b.id] ?? order.length + original[b.id]!),
    );
    return list;
  });

  List<WalletItemBase> get hotWallets => wallets.where((wallet) => wallet.hasLocalKey).toList();
  List<WalletItemBase> get watchOnlyWallets => wallets.where((wallet) => !wallet.hasLocalKey).toList();

  List<int> _idsOf(List<int>? walletIds) {
    if (walletIds != null) {
      final existing = walletIds.where((id) => wallets.any((wallet) => wallet.id == id)).toList();
      if (existing.isNotEmpty) return existing;
    }
    return [for (final wallet in wallets) wallet.id];
  }

  int balanceOf(int walletId) =>
      isFakeBalance
          ? _preferenceProvider.getFakeBalance(walletId).round()
          : _walletProvider.getWalletBalance(walletId).total;

  int totalBalance([List<int>? walletIds]) => _idsOf(walletIds).fold(0, (sum, id) => sum + balanceOf(id));

  int? priceOf(FiatCode fiatCode) => _priceProvider.getBitcoinPriceForFiat(fiatCode);

  int? fiatValueOf(int sats, FiatCode fiatCode) {
    final price = priceOf(fiatCode);
    return price == null ? null : FiatUtil.calculateFiatAmount(sats, price);
  }

  List<double>? _closesOf(FiatCode fiatCode) {
    if (!_dailyCloses.containsKey(fiatCode) && _loadingCloses.add(fiatCode)) {
      unawaited(_loadCloses(fiatCode));
    }
    return _dailyCloses[fiatCode];
  }

  Future<void> _loadCloses(FiatCode fiatCode) async {
    List<double>? closes;
    try {
      closes = await _historicalPriceService.fetchDailyCloses(fiatCode);
    } catch (_) {
      closes = null;
    }
    if (_disposed) return;
    _loadingCloses.remove(fiatCode);
    _dailyCloses[fiatCode] = closes;
    notifyListeners();
  }

  /// 최근 [days]일의 시세: 지난 날들은 일별 종가, 마지막은 현재 시세. 시세나 종가가 없으면 null.
  List<int>? dailyPrices(FiatCode fiatCode, {int days = defaultDays}) {
    final closes = _closesOf(fiatCode);
    final price = priceOf(fiatCode);
    if (closes == null || closes.isEmpty || price == null) return null;
    final past = closes.length >= days - 1 ? closes.sublist(closes.length - (days - 1)) : closes;
    return [for (final close in past) close.round(), price];
  }

  /// 어제 종가 대비 현재 시세 변화율. 시세나 과거 종가가 없으면 null.
  double? priceChange24h(FiatCode fiatCode) {
    final closes = _closesOf(fiatCode);
    final price = priceOf(fiatCode);
    if (closes == null || closes.isEmpty || price == null) return null;
    return HomeWidgetMath.changeRate(closes.last, price);
  }

  List<int> dailyBalances({List<int>? walletIds, int days = defaultDays}) {
    final ids = _idsOf(walletIds);
    return _cached('daily:$ids:$days:$isFakeBalance', () {
      if (isFakeBalance) {
        return HomeWidgetMath.fakeTrend(
          end: totalBalance(ids),
          seed: HomeWidgetMath.seed(['trend', ...ids, days]),
          points: days,
        );
      }
      final perWallet = [
        for (final id in ids)
          HomeWidgetMath.dailyBalances(_walletProvider.getTransactionRecordList(id), balanceOf(id), _now(), days),
      ];
      return [for (var i = 0; i < days; i++) perWallet.fold(0, (sum, balances) => sum + balances[i])];
    });
  }

  static const recentTransactionLimit = 3;

  /// 기간과 상관없이 가장 최근 거래부터 [recentTransactionLimit]개. 아직 확인되지 않은 거래가 먼저 온다.
  List<HomeRecentTransaction> recentTransactions({List<int>? walletIds}) {
    final ids = _idsOf(walletIds);
    return _cached('recent:$ids:$isFakeBalance', () {
      final names = {for (final wallet in wallets) wallet.id: wallet.name};
      if (isFakeBalance) {
        return HomeWidgetMath.fakeRecentTransactions(
          seed: HomeWidgetMath.seed(['recent', ...ids]),
          now: _now(),
          wallets: [for (final id in ids) (walletId: id, walletName: names[id] ?? '', balance: balanceOf(id))],
        );
      }
      final all = [
        for (final id in ids)
          for (final tx in _walletProvider.getTransactionRecordList(id))
            HomeRecentTransaction(
              walletId: id,
              walletName: names[id] ?? '',
              amount: tx.amount,
              time: tx.timestamp,
              type: tx.transactionType,
              status: TransactionUtil.getStatus(tx),
            ),
      ];
      bool pending(HomeRecentTransaction tx) =>
          tx.status == TransactionStatus.receiving ||
          tx.status == TransactionStatus.sending ||
          tx.status == TransactionStatus.selfsending;
      all.sort((a, b) {
        if (pending(a) != pending(b)) return pending(a) ? -1 : 1;
        return b.time.compareTo(a.time);
      });
      return all.take(recentTransactionLimit).toList();
    });
  }

  List<HomeDailyActivity> dailyActivity({List<int>? walletIds, int days = defaultDays}) {
    final ids = _idsOf(walletIds);
    return _cached('activity:$ids:$days:$isFakeBalance', () {
      final now = _now();
      if (isFakeBalance) {
        return HomeWidgetMath.fakeDailyActivity(
          seed: HomeWidgetMath.seed(['activity', now.year, now.month, now.day, ...ids]),
          now: now,
          days: days,
        );
      }
      final start = HomeWidgetMath.lastDays(now, days).first;
      final transactions = _walletProvider.getConfirmedTransactionRecordListWithinDateRange(ids, Tuple2(start, now));
      return HomeWidgetMath.dailyActivity(transactions, now, days);
    });
  }

  /// 기간 동안의 받기·보내기·정리 횟수와 수량
  HomeActivityTotals activityTotals({List<int>? walletIds, int days = defaultDays}) {
    final ids = _idsOf(walletIds);
    return _cached('totals:$ids:$days:$isFakeBalance', () {
      final now = _now();
      if (isFakeBalance) {
        return HomeWidgetMath.fakeActivityTotals(
          seed: HomeWidgetMath.seed(['totals', now.year, now.month, now.day, ...ids, days]),
          days: dailyActivity(walletIds: walletIds, days: days),
          balance: totalBalance(ids),
        );
      }
      final start = HomeWidgetMath.lastDays(now, days).first;
      return HomeWidgetMath.activityTotals(
        _walletProvider.getConfirmedTransactionRecordListWithinDateRange(ids, Tuple2(start, now)),
      );
    });
  }

  /// 첫 거래일부터 오늘까지의 일수(최소 7일). 가짜 잔액이면 실제 사용 기간이 드러나지 않게 1년으로 본다.
  int daysSinceFirstTransaction({List<int>? walletIds}) {
    if (isFakeBalance) return 365;
    final ids = _idsOf(walletIds);
    return _cached('first:$ids', () {
      DateTime? first;
      for (final id in ids) {
        for (final tx in _walletProvider.getTransactionRecordList(id)) {
          if (first == null || tx.timestamp.isBefore(first)) first = tx.timestamp;
        }
      }
      if (first == null) return defaultDays;
      final today = _now();
      final days =
          DateTime(today.year, today.month, today.day).difference(DateTime(first.year, first.month, first.day)).inDays +
          1;
      return days < defaultDays ? defaultDays : days;
    });
  }

  /// UTXO 한눈에 보기의 금액 구간 색. 위젯 구간 ≥0.1 / 0.01~0.1 / 0.001~0.01 / <0.001 순
  List<Color> get utxoBucketColors {
    final theme = _preferenceProvider.utxoTierTheme;
    return [UtxoTier.huge, UtxoTier.large, UtxoTier.medium, UtxoTier.small].map(theme.bg).toList();
  }

  HomeUtxoBuckets utxoBuckets({List<int>? walletIds}) {
    final ids = _idsOf(walletIds);
    return _cached('utxo:$ids:$isFakeBalance', () {
      if (isFakeBalance) {
        return HomeWidgetMath.fakeUtxoBuckets(seed: HomeWidgetMath.seed(['utxo', ...ids]), total: totalBalance(ids));
      }
      return HomeWidgetMath.utxoBuckets([
        for (final id in ids)
          for (final utxo in _walletProvider.getUtxoList(id)) utxo.amount,
      ]);
    });
  }

  /// 목표 수량이 있는 지갑들의 잔액 합계 / 목표 합계. 목표가 있는 지갑이 없으면 null.
  HomeSavingsGoal? savingsGoal({List<int>? walletIds}) {
    final withTarget = [
      for (final id in _idsOf(walletIds))
        if (_targetSatsOf(id) case final target? when target > 0) (id: id, target: target),
    ];
    if (withTarget.isEmpty) return null;
    return HomeSavingsGoal(
      balance: withTarget.fold(0, (sum, entry) => sum + balanceOf(entry.id)),
      target: withTarget.fold(0, (sum, entry) => sum + entry.target),
    );
  }

  List<HomeBalanceShare> balanceShares({List<int>? walletIds, required String othersName}) {
    final ids = _idsOf(walletIds).toSet();
    return HomeWidgetMath.balanceShares([
      for (final wallet in wallets)
        if (ids.contains(wallet.id))
          HomeBalanceShare(
            walletId: wallet.id,
            name: wallet.name,
            balance: balanceOf(wallet.id),
            colorIndex: wallet.colorIndex,
          ),
    ], othersName: othersName);
  }

  DateTime? lastTransactionTime(int walletId) => _cached('last:$walletId', () {
    final transactions = _walletProvider.getTransactionRecordList(walletId);
    if (transactions.isEmpty) return null;
    return transactions.map((tx) => tx.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);
  });

  @override
  void dispose() {
    _disposed = true;
    _priceWaitTimer?.cancel();
    _walletProvider.walletLoadStateNotifier.removeListener(_onDataChanged);
    _walletProvider.walletItemListNotifier.removeListener(_onDataChanged);
    _preferenceProvider.removeListener(_onDataChanged);
    _walletUpdates?.removeListener(_onDataChanged);
    _priceProvider.removeListener(notifyListeners);
    super.dispose();
  }
}
