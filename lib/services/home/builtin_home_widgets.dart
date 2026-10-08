import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/providers/view_model/home/hodl_insights_view_model.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/screens/home/hodl_insights_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart' show kEntryPointWalletHome;
import 'package:coconut_wallet/services/home/home_widget_math.dart';
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_widget_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

typedef HomeWidgetBuilder = Widget Function(BuildContext context, HomeWidgetsViewModel viewModel, HomeItem item);
typedef HomeWidgetLoading = bool Function(HomeWidgetsViewModel viewModel, HomeWidgetSettings settings);

bool _walletDataLoading(HomeWidgetsViewModel viewModel, HomeWidgetSettings settings) => viewModel.isWalletDataLoading;

const _walletScopeSettings = HomeWidgetSettingsSpec(wallets: true);

class BuiltinHomeWidget extends HomeItemDefinition {
  final String Function() name;
  final HomeWidgetBuilder builder;
  final HomeWidgetLoading isLoading;

  /// 누르면 여는 화면. 없으면 누를 수 없는 정보 위젯이다.
  final void Function(BuildContext context, HomeItem item)? onTap;

  BuiltinHomeWidget({
    required super.id,
    HomeSpan? span,
    List<HomeSpan>? spans,
    required super.category,
    required this.name,
    required this.builder,
    this.isLoading = _walletDataLoading,
    this.onTap,
    super.settings,
  }) : super(kind: HomeItemKind.widget, supportedSpans: spans ?? [span!], needsConfigureBeforeAdd: !settings.isEmpty);

  @override
  String displayName() => name();

  @override
  Widget build(BuildContext context, HomeItem item) {
    final viewModel = context.watch<HomeWidgetsViewModel>();
    if (isLoading(viewModel, _settingsOf(item))) {
      return HomeWidgetSkeleton(wide: item.span == HomeSpan.wide);
    }
    final view = builder(context, viewModel, item);
    final onTap = this.onTap;
    if (onTap == null) return view;
    return HomeWidgetPressable(
      key: ValueKey('home-widget-tap-${item.id}'),
      onTap: () => onTap(context, item),
      child: view,
    );
  }
}

/// 위젯 설정의 지갑 범위. 없으면 전체 지갑(합계 제외 지갑 빼고).
List<int>? walletIdsOf(HomeItem item) => HomeWidgetSettings.fromConfiguration(item.configuration).walletIds;

HomeWidgetSettings _settingsOf(HomeItem item) => HomeWidgetSettings.fromConfiguration(item.configuration);

List<FiatCode> fiatsWithDefaultFirst(FiatCode selected) => [
  selected,
  ...FiatCode.values.where((fiat) => fiat != selected),
];

FiatCode _fiatOf(HomeWidgetsViewModel viewModel, HomeWidgetSettings settings) =>
    settings.fiats?.first ?? viewModel.fiat;

List<FiatCode> _fiatsOf(HomeWidgetsViewModel viewModel, HomeWidgetSettings settings, int max) =>
    (settings.fiats ?? fiatsWithDefaultFirst(viewModel.fiat)).take(max).toList();

/// 누른 위젯의 지갑 범위·기간으로 인사이트를 열고, 그 위젯에 해당하는 구역으로 이동한다.
void Function(BuildContext context, HomeItem item) _openInsights(HodlInsightsSection section) => (context, item) {
  final settings = _settingsOf(item);
  final period = settings.period ?? HomeWidgetPeriod.week;
  HodlInsightsScreen.open(
    context,
    walletIds: settings.walletIds,
    balancePeriod: section == HodlInsightsSection.balance ? period : HomeWidgetPeriod.week,
    activityPeriod: section == HodlInsightsSection.activity ? period : HomeWidgetPeriod.week,
    section: section,
  );
};

/// 거래 분석 막대. 1주는 하루씩, 1개월은 5일씩, 3개월은 2주씩, 1년은 최근 12개월을 달력 월로 묶는다.
/// 전체는 첫 거래부터의 일수에 맞춰 같은 규칙을 고르고, 12개월이 넘으면 여러 달씩 묶는다.
({List<HomeDailyActivity> bars, bool monthly, int days}) activityBarsFor(
  HomeWidgetsViewModel viewModel, {
  List<int>? walletIds,
  required HomeWidgetPeriod period,
}) {
  final now = DateTime.now();
  final allDays = period == HomeWidgetPeriod.all ? viewModel.daysSinceFirstTransaction(walletIds: walletIds) : 0;
  final unit = switch (period) {
    HomeWidgetPeriod.all when allDays <= 7 => HomeWidgetPeriod.week,
    HomeWidgetPeriod.all when allDays <= 31 => HomeWidgetPeriod.month,
    HomeWidgetPeriod.all when allDays <= 92 => HomeWidgetPeriod.threeMonths,
    HomeWidgetPeriod.all => HomeWidgetPeriod.year,
    _ => period,
  };
  final days = switch (period) {
    HomeWidgetPeriod.year => HomeWidgetMath.daysSinceMonthsAgo(now, 12),
    HomeWidgetPeriod.all => allDays,
    _ => period.days,
  };
  final daily = viewModel.dailyActivity(walletIds: walletIds, days: days);
  final bars = switch (unit) {
    HomeWidgetPeriod.week => daily,
    HomeWidgetPeriod.month => HomeWidgetMath.groupActivity(daily, groupDays: 5),
    HomeWidgetPeriod.threeMonths => HomeWidgetMath.groupActivity(daily, groupDays: 14),
    _ => HomeWidgetMath.groupActivity(HomeWidgetMath.groupActivityByMonth(daily), maxBars: 12),
  };
  return (bars: bars, monthly: unit == HomeWidgetPeriod.year, days: days);
}

/// 날짜 라벨은 기간과 상관없이 [count]개만 고르게 보여 준다.
List<String> _dayLabels(int days, {int count = 7}) {
  final all = HomeWidgetMath.lastDays(DateTime.now(), days);
  if (all.length <= count) return [for (final day in all) formatHomeShortDate(day)];
  return [for (var i = 0; i < count; i++) formatHomeShortDate(all[(i * (all.length - 1) / (count - 1)).round()])];
}

String _btc(HomeWidgetsViewModel viewModel, int sats) => viewModel.unit.displayBitcoinAmount(sats, withUnit: true);

String _btcNumber(HomeWidgetsViewModel viewModel, int sats, {bool roundedTo4 = false}) =>
    roundedTo4 && viewModel.unit.isBtcUnit
        ? (sats / 100000000).toStringAsFixed(4)
        : viewModel.unit.displayBitcoinAmount(sats);

HomeAmount _btcAmount(HomeWidgetsViewModel viewModel, int sats, {bool roundedTo4 = false}) => HomeAmount(
  _btcNumber(viewModel, sats, roundedTo4: roundedTo4),
  viewModel.unit.symbol,
  unitFirst: viewModel.unit.isPrefixSymbol,
);

HomeAmount _fiatAmount(int? amount, FiatCode fiat) =>
    amount == null
        ? const HomeAmount('-', '')
        : HomeAmount(amount.toThousandsSeparatedString(), fiat.symbol, unitFirst: true);

List<HomeItemDefinition> builtinHomeWidgets() => [
  BuiltinHomeWidget(
    id: HomeItemIds.bitcoinBalanceTrend,
    onTap: _openInsights(HodlInsightsSection.balance),
    spans: const [HomeSpan.small, HomeSpan.wide],
    category: HomeItemCategory.balance,
    settings: const HomeWidgetSettingsSpec(
      wallets: true,
      period: true,
      fakeBalance: true,
      sizes: [HomeSpan.wide, HomeSpan.small],
    ),
    isLoading: (viewModel, settings) => viewModel.isWalletDataLoading || viewModel.isPriceLoading(viewModel.fiat),
    name: () => t.home_widgets.bitcoin_balance_trend,
    builder: (context, viewModel, item) {
      final settings = _settingsOf(item);
      final values = viewModel.dailyBalances(walletIds: settings.walletIds, days: settings.days);
      if (item.span == HomeSpan.wide) {
        final delta = values.last - values.first;
        return BalanceChangeOverTimeView(
          balance: _btcAmount(viewModel, values.last),
          fiatText: formatHomeFiat(viewModel.fiatValueOf(values.last, viewModel.fiat), viewModel.fiat),
          rate: HomeWidgetMath.changeRate(values.first, values.last),
          deltaText: '${delta >= 0 ? '+' : '-'} ${_btc(viewModel, delta.abs())}',
          deltaSign: delta.sign,
          values: values,
          dayLabels: _dayLabels(values.length),
        );
      }
      return BitcoinBalanceTrendView(
        balance: _btcAmount(viewModel, values.last),
        fiatText: formatHomeFiat(viewModel.fiatValueOf(values.last, viewModel.fiat), viewModel.fiat),
        rate: HomeWidgetMath.changeRate(values.first, values.last),
        values: values,
      );
    },
  ),
  BuiltinHomeWidget(
    id: HomeItemIds.bitcoinBalanceByFiat,
    onTap: _openInsights(HodlInsightsSection.balance),
    span: HomeSpan.small,
    category: HomeItemCategory.balance,
    settings: const HomeWidgetSettingsSpec(
      wallets: true,
      currencies: HomeWidgetCurrencyMode.multiple,
      maxCurrencies: 4,
      fakeBalance: true,
    ),
    isLoading:
        (viewModel, settings) =>
            viewModel.isWalletDataLoading || viewModel.isPriceLoading(_fiatsOf(viewModel, settings, 4).first),
    name: () => t.home_widgets.bitcoin_balance_by_fiat,
    builder: (context, viewModel, item) {
      final settings = _settingsOf(item);
      final balance = viewModel.totalBalance(settings.walletIds);
      return BitcoinBalanceByFiatView(
        balance: _btcAmount(viewModel, balance),
        rows: [
          for (final fiat in _fiatsOf(viewModel, settings, 4))
            HomeFiatRow(
              fiat: fiat,
              amountText: formatHomeFiat(viewModel.fiatValueOf(balance, fiat), fiat, withSymbol: false),
              rate: viewModel.priceChange24h(fiat),
            ),
        ],
      );
    },
  ),
  BuiltinHomeWidget(
    id: HomeItemIds.fiatPriceTrend,
    span: HomeSpan.small,
    category: HomeItemCategory.balance,
    settings: const HomeWidgetSettingsSpec(
      currencies: HomeWidgetCurrencyMode.single,
      period: true,
      periods: [HomeWidgetPeriod.week, HomeWidgetPeriod.month],
    ),
    isLoading:
        (viewModel, settings) =>
            viewModel.isPriceLoading(_fiatOf(viewModel, settings)) ||
            viewModel.isDailyClosesLoading(_fiatOf(viewModel, settings)),
    name: () => t.home_widgets.fiat_price_trend,
    builder: (context, viewModel, item) {
      final settings = _settingsOf(item);
      final fiat = _fiatOf(viewModel, settings);
      final values = viewModel.dailyPrices(fiat, days: settings.days) ?? const <int>[];
      return FiatPriceTrendView(
        price: _fiatAmount(viewModel.priceOf(fiat), fiat),
        pairLabel: 'BTC · ${fiat.code}',
        rate: values.length < 2 ? null : HomeWidgetMath.changeRate(values.first, values.last),
        values: values,
      );
    },
  ),
  BuiltinHomeWidget(
    id: HomeItemIds.fiatValues,
    span: HomeSpan.small,
    category: HomeItemCategory.balance,
    settings: const HomeWidgetSettingsSpec(currencies: HomeWidgetCurrencyMode.multiple, maxCurrencies: 3),
    isLoading: (viewModel, settings) => viewModel.isPriceLoading(_fiatsOf(viewModel, settings, 3).first),
    name: () => t.home_widgets.fiat_values,
    builder:
        (context, viewModel, item) => FiatValuesView(
          rows: [
            for (final fiat in _fiatsOf(viewModel, _settingsOf(item), 3))
              HomeFiatRow(
                fiat: fiat,
                amountText: formatHomeFiat(viewModel.priceOf(fiat), fiat, withSymbol: false),
                rate: viewModel.priceChange24h(fiat),
              ),
          ],
        ),
  ),
  ...walletStackDefinitions(),
  BuiltinHomeWidget(
    id: HomeItemIds.balanceByWallet,
    onTap: _openInsights(HodlInsightsSection.balanceByWallet),
    span: HomeSpan.wide,
    category: HomeItemCategory.wallets,
    settings: _walletScopeSettings,
    name: () => t.home_widgets.balance_by_wallet,
    builder: (context, viewModel, item) {
      final ids = walletIdsOf(item);
      return BalanceByWalletView(
        shares: viewModel.balanceShares(walletIds: ids, othersName: t.home_widgets.others),
        total: _btcAmount(viewModel, viewModel.totalBalance(ids), roundedTo4: true),
        amountText: (sats) => _btcNumber(viewModel, sats, roundedTo4: true),
      );
    },
  ),
  BuiltinHomeWidget(
    id: HomeItemIds.recentTransactions,
    span: HomeSpan.wide,
    category: HomeItemCategory.activities,
    settings: _walletScopeSettings,
    name: () => t.home_widgets.recent_transactions,
    builder:
        (context, viewModel, item) => RecentTransactionsView(
          transactions: viewModel.recentTransactions(walletIds: walletIdsOf(item)),
          amountText: (sats) => _btc(viewModel, sats),
          now: DateTime.now(),
          onTransactionTap:
              (walletId) => Navigator.pushNamed(
                context,
                AppRouteNames.walletDetail,
                arguments: WalletDetailRouteArgs(id: walletId, entryPoint: kEntryPointWalletHome),
              ),
        ),
  ),
  BuiltinHomeWidget(
    id: HomeItemIds.transactionActivity,
    onTap: _openInsights(HodlInsightsSection.activity),
    span: HomeSpan.wide,
    category: HomeItemCategory.activities,
    settings: const HomeWidgetSettingsSpec(wallets: true, period: true),
    name: () => t.home_widgets.transaction_activity,
    builder: (context, viewModel, item) {
      final settings = _settingsOf(item);
      final bars = activityBarsFor(
        viewModel,
        walletIds: settings.walletIds,
        period: settings.period ?? HomeWidgetPeriod.week,
      );
      return TransactionActivityView(days: bars.bars, rangeEnd: DateTime.now(), monthly: bars.monthly);
    },
  ),
  BuiltinHomeWidget(
    id: HomeItemIds.savingsGoal,
    onTap: _openInsights(HodlInsightsSection.goal),
    span: HomeSpan.small,
    category: HomeItemCategory.hodl,
    settings: const HomeWidgetSettingsSpec(wallets: true, goals: true),
    name: () => t.home_widgets.savings_goal,
    builder:
        (context, viewModel, item) => SavingsGoalView(
          goal: viewModel.savingsGoal(walletIds: walletIdsOf(item)),
          amountText: (sats) => _btc(viewModel, sats),
        ),
  ),
  BuiltinHomeWidget(
    id: HomeItemIds.utxoStatus,
    onTap: _openInsights(HodlInsightsSection.utxo),
    span: HomeSpan.small,
    category: HomeItemCategory.hodl,
    settings: _walletScopeSettings,
    name: () => t.home_widgets.utxo_status,
    builder:
        (context, viewModel, item) => UtxoStatusView(
          buckets: viewModel.utxoBuckets(walletIds: walletIdsOf(item)),
          bucketColors: viewModel.utxoBucketColors,
        ),
  ),
];
