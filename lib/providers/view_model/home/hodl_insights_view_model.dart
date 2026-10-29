import 'dart:async';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:coconut_wallet/services/home/home_widget_math.dart';
import 'package:flutter/foundation.dart';

/// 홈 위젯을 통해 진입했을 때 먼저 보여 줄 구역
enum HodlInsightsSection { balance, goal, balanceByWallet, utxo, activity }

/// 호들 인사이트 화면
/// 데이터는 홈 위젯과 같은 [HomeWidgetsViewModel]에서 받고, 화면의 기간·지갑 범위만 들고 있는다.
class HodlInsightsViewModel extends ChangeNotifier {
  static const periods = HomeWidgetPeriod.values;

  /// 잔액 추이 그래프에 그리는 최대 점의 수
  static const maxChartPoints = 60;

  final HomeWidgetsViewModel _data;
  HomeWidgetPeriod _balancePeriod;
  HomeWidgetPeriod _activityPeriod;
  List<int>? _walletIds;
  final SharedPrefsRepository? _selectionRepository;
  bool _isSavingWalletSelection = false;
  bool _disposed = false;
  Future<void> _selectionWrite = Future<void>.value();
  bool get isSavingWalletSelection => _isSavingWalletSelection;
  final ValueChanged<List<int>?>? onWalletSelectionPruned;

  /// 처음 열 때 스크롤하고 잠깐 강조할 구역
  /// 맨 위(총 잔액)면 스크롤하지 않는다.
  final HodlInsightsSection initialSection;

  HodlInsightsViewModel(
    this._data, {
    this.initialSection = HodlInsightsSection.balance,
    List<int>? walletIds,
    this.onWalletSelectionPruned,
    // 상세 화면 등의 미리보기는 저장하지 않는다. 인사이트 화면에서만 명시적으로 전달한다.
    SharedPrefsRepository? selectionRepository,
    HomeWidgetPeriod balancePeriod = HomeWidgetPeriod.week,
    HomeWidgetPeriod activityPeriod = HomeWidgetPeriod.week,
  }) : _selectionRepository = selectionRepository,
       _walletIds =
           selectionRepository == null ? walletIds : selectionRepository.getHodlInsightsWalletIds(fallback: walletIds),
       _balancePeriod = balancePeriod,
       _activityPeriod = activityPeriod {
    _pruneWalletSelection();
    _data.addListener(_onDataChanged);
  }

  void _pruneWalletSelection() {
    if (_data.isWalletDataLoading || _walletIds == null) return;
    final existingIds = _data.wallets.map((wallet) => wallet.id).toSet();
    final validIds = _walletIds!.where(existingIds.contains).toList();
    final nextIds = validIds.isEmpty ? null : validIds;
    if (listEquals(nextIds, _walletIds)) return;
    _walletIds = nextIds;
    onWalletSelectionPruned?.call(nextIds == null ? null : List.unmodifiable(nextIds));
    if (_selectionRepository != null) unawaited(_persistPrunedWalletIds(nextIds));
  }

  Future<void> _writeSelection(List<int>? ids, {bool onlyIfCurrent = false, VoidCallback? onSaved}) {
    final snapshot = ids == null ? null : List<int>.unmodifiable(ids);
    final write = _selectionWrite.then((_) async {
      if (onlyIfCurrent && !listEquals(_walletIds, snapshot)) return;
      await _selectionRepository!.setHodlInsightsWalletIds(snapshot);
      onSaved?.call();
    });
    // 자동 정리와 수동 저장을 직렬화해 이전 쓰기가 최신 선택을 덮어쓰지 않도록 한다.
    _selectionWrite = write.catchError((Object _) {});
    return write;
  }

  Future<void> _persistPrunedWalletIds(List<int>? ids) async {
    try {
      await _writeSelection(ids, onlyIfCurrent: true);
    } catch (error) {
      Logger.error('Failed to persist pruned insights wallet selection: $error');
    }
  }

  /// 저장 성공 후에만 화면 선택을 변경한다. 재사용되는 미리보기 모델은 저장하지 않는다.
  Future<bool> saveWalletSelection(List<int>? ids) async {
    if (_disposed || _isSavingWalletSelection || _selectionRepository == null) return false;
    _isSavingWalletSelection = true;
    final snapshot = ids == null ? null : List<int>.unmodifiable(ids);
    notifyListeners();
    try {
      await _writeSelection(
        snapshot,
        onSaved: () {
          if (_disposed) return;
          setWalletIds(snapshot);
          _data.refresh();
        },
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _isSavingWalletSelection = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _onDataChanged() {
    _pruneWalletSelection();
    notifyListeners();
  }

  HomeWidgetsViewModel get data => _data;
  HomeWidgetPeriod get balancePeriod => _balancePeriod;
  HomeWidgetPeriod get activityPeriod => _activityPeriod;
  List<int>? get walletIds => _walletIds;
  bool get isLoading => _data.isWalletDataLoading;

  /// 지갑이 하나도 없으면 인사이트 대신 지갑 추가를 권한다.
  bool get hasNoWallets => !isLoading && _data.wallets.isEmpty;

  void selectBalancePeriod(HomeWidgetPeriod period) {
    if (_balancePeriod == period) return;
    _balancePeriod = period;
    notifyListeners();
  }

  void selectActivityPeriod(HomeWidgetPeriod period) {
    if (_activityPeriod == period) return;
    _activityPeriod = period;
    notifyListeners();
  }

  void setWalletIds(List<int>? walletIds) {
    _walletIds = walletIds;
    notifyListeners();
  }

  int get balanceDays => switch (_balancePeriod) {
    HomeWidgetPeriod.all => _data.daysSinceFirstTransaction(walletIds: _walletIds),
    _ => _balancePeriod.days,
  };

  List<int> get _dailyBalances => _data.dailyBalances(walletIds: _walletIds, days: balanceDays);

  int get balance => _data.totalBalance(_walletIds);

  /// 그래프에 그릴 잔액. 첫날과 오늘은 항상 포함한다
  List<int> get chartBalances => sampleEvenly(_dailyBalances, maxChartPoints);

  /// [chartBalances]의 각 점이 가리키는 날
  List<DateTime> get chartBalanceDays => sampleEvenly(HomeWidgetMath.lastDays(_data.now, balanceDays), maxChartPoints);

  /// 그래프 아래 날짜 7개
  List<DateTime> get chartDays {
    final days = HomeWidgetMath.lastDays(_data.now, balanceDays);
    return sampleEvenly(days, 7);
  }

  bool get chartUsesMonths => balanceDays > HomeWidgetPeriod.threeMonths.days + 2;

  double? get changeRate {
    final values = _dailyBalances;
    return HomeWidgetMath.changeRate(values.first, values.last);
  }

  int get changeSats {
    final values = _dailyBalances;
    return values.last - values.first;
  }

  HomeSavingsGoal? get goal => _data.savingsGoal(walletIds: _walletIds);

  List<HomeBalanceShare> balanceShares(String othersName) =>
      _data.balanceShares(walletIds: _walletIds, othersName: othersName);

  HomeUtxoBuckets get utxoBuckets => _data.utxoBuckets(walletIds: _walletIds);

  ({List<HomeDailyActivity> bars, bool monthly, int days}) get activityBars =>
      activityBarsFor(_data, walletIds: _walletIds, period: _activityPeriod);

  HomeActivityTotals get activityTotals => _data.activityTotals(walletIds: _walletIds, days: activityBars.days);

  static List<T> sampleEvenly<T>(List<T> values, int count) {
    if (values.length <= count) return values;
    return [for (var i = 0; i < count; i++) values[(i * (values.length - 1) / (count - 1)).round()]];
  }

  @override
  void dispose() {
    _disposed = true;
    _data.removeListener(_onDataChanged);
    if (!_data.usesFakeBalance) _data.dispose();
    super.dispose();
  }
}
