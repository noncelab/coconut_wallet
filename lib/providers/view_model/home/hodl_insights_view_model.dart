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

  /// 처음 열 때 스크롤하고 잠깐 강조할 구역
  /// 맨 위(총 잔액)면 스크롤하지 않는다.
  final HodlInsightsSection initialSection;

  HodlInsightsViewModel(
    this._data, {
    this.initialSection = HodlInsightsSection.balance,
    List<int>? walletIds,
    HomeWidgetPeriod balancePeriod = HomeWidgetPeriod.week,
    HomeWidgetPeriod activityPeriod = HomeWidgetPeriod.week,
  }) : _walletIds = walletIds,
       _balancePeriod = balancePeriod,
       _activityPeriod = activityPeriod {
    _data.addListener(notifyListeners);
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
  List<DateTime> get chartBalanceDays =>
      sampleEvenly(HomeWidgetMath.lastDays(DateTime.now(), balanceDays), maxChartPoints);

  /// 그래프 아래 날짜 7개
  List<DateTime> get chartDays {
    final days = HomeWidgetMath.lastDays(DateTime.now(), balanceDays);
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
    _data.removeListener(notifyListeners);
    if (!_data.usesFakeBalance) _data.dispose();
    super.dispose();
  }
}
