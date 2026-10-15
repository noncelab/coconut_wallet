import 'dart:math' as math;
import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/view_model/home/hodl_insights_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/home/home_widget_math.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_history_period_chips.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/transaction/card/transaction_item_card.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_item_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

const walletBalanceHistoryHeroTag = 'hodl-balance-history';

Widget walletBalanceHistoryFlight(
  BuildContext context,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext from,
  BuildContext to,
) {
  Widget fitted(BuildContext heroContext) {
    final size = (heroContext.findRenderObject() as RenderBox).size;
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(width: size.width, height: size.height, child: (heroContext.widget as Hero).child),
    );
  }

  final compact = direction == HeroFlightDirection.push ? from : to;
  final detail = direction == HeroFlightDirection.push ? to : from;
  return AnimatedBuilder(
    animation: animation,
    builder:
        (_, __) => Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: 1 - animation.value, child: fitted(compact)),
            Opacity(opacity: animation.value, child: fitted(detail)),
          ],
        ),
  );
}

class WalletBalanceHistoryScreen extends StatefulWidget {
  final HodlInsightsViewModel viewModel;
  const WalletBalanceHistoryScreen({super.key, required this.viewModel});

  static Future<void> open(BuildContext context, HodlInsightsViewModel viewModel) => Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      settings: const RouteSettings(name: '/wallet-balance-history'),
      opaque: false,
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => WalletBalanceHistoryScreen(viewModel: viewModel),
      transitionsBuilder:
          (_, animation, __, child) =>
              FadeTransition(opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)), child: child),
    ),
  );

  @override
  State<WalletBalanceHistoryScreen> createState() => _WalletBalanceHistoryScreenState();
}

class _WalletBalanceHistoryScreenState extends State<WalletBalanceHistoryScreen> {
  late HomeWidgetPeriod _period;
  late final DateTime _today;
  late final int _days;
  late final int _allDays;
  late double _span;
  late double _end;
  int? _selected;
  bool _changedOnly = false;
  final Set<int> _expanded = {};
  double _startSpan = 1;
  double _startEnd = 0;
  Offset _startPosition = Offset.zero;
  bool _pinching = false;

  HodlInsightsViewModel get vm => widget.viewModel;
  List<DateTime> get _dates => HomeWidgetMath.lastDays(_today, _days);
  List<int> get _balances => vm.data.dailyBalances(walletIds: vm.walletIds, days: _days);
  int get _first => (_end - _span + 1).round().clamp(0, _days - 1);
  int get _last => _end.round().clamp(_first, _days - 1);

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _allDays = math.max(2, vm.data.daysSinceFirstTransaction(walletIds: vm.walletIds));
    _days = math.max(365, _allDays);
    _period = vm.balancePeriod;
    _span = (_period == HomeWidgetPeriod.all ? _allDays : _period.days).toDouble();
    _end = (_days - 1).toDouble();
    vm.data.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    vm.data.removeListener(_refresh);
    super.dispose();
  }

  void _selectPeriod(HomeWidgetPeriod period) => setState(() {
    _period = period;
    _span = (period == HomeWidgetPeriod.all ? _allDays : period.days).toDouble();
    _end = (_days - 1).toDouble();
    if (_selected != null) _selected = _selected!.clamp(_first, _last);
    _expanded.clear();
  });

  void _syncPeriod() {
    if ((_span - _allDays).abs() < 0.5 && (_period == HomeWidgetPeriod.all || _allDays > 365)) {
      _period = HomeWidgetPeriod.all;
      return;
    }
    final choices = [...HomeWidgetPeriod.widgetPeriods, HomeWidgetPeriod.all];
    int daysOf(HomeWidgetPeriod period) => period == HomeWidgetPeriod.all ? _allDays : period.days;
    _period = choices.reduce(
      (a, b) => (math.log(_span / daysOf(a))).abs() <= (math.log(_span / daysOf(b))).abs() ? a : b,
    );
  }

  void _focusAt(double x, double width) {
    final index = (_first + (x / width).clamp(0.0, 1.0) * (_last - _first)).round();
    if (index != _selected) {
      final balances = _balances;
      if (index > 0 && balances[index] != balances[index - 1]) vibrateExtraLight();
      setState(() {
        _selected = index;
        _expanded.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final balances = _balances;
    final dates = _dates;
    final selected = _selected;
    final unit = vm.data.unit;
    return Scaffold(
      backgroundColor: colors.homeBackground,
      appBar: CoconutAppBar.build(context: context, title: t.wallet_list.header.balance_history),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              Text(
                selected == null ? t.hodl_insights.total_balance : DateFormat('yyyy.MM.dd').format(dates[selected]),
                style: CoconutTypography.body2_14.copyWith(color: colors.secondaryText),
              ),
              const SizedBox(height: 8),
              FittedBox(
                child: Text(
                  unit.displayBitcoinAmount(balances[selected ?? balances.length - 1], withUnit: true),
                  style: CoconutTypography.heading2_28_NumberBold.copyWith(color: colors.primaryText),
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: BalanceHistoryPeriodChips(selected: _period, onSelected: _selectPeriod),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final height = selected == null ? constraints.maxHeight : constraints.maxHeight * 0.52;
                    return TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 360),
                      curve: Curves.easeInOutCubic,
                      tween: Tween(end: height),
                      builder:
                          (context, chartHeight, _) => Stack(
                            children: [
                              SizedBox(
                                height: chartHeight,
                                width: double.infinity,
                                child: Hero(
                                  tag: walletBalanceHistoryHeroTag,
                                  flightShuttleBuilder: walletBalanceHistoryFlight,
                                  child: Material(
                                    color: colors.homeSurface,
                                    borderRadius: BorderRadius.circular(20),
                                    clipBehavior: Clip.antiAlias,
                                    child: _chart(balances, dates),
                                  ),
                                ),
                              ),
                              if (selected != null && chartHeight + 12 < constraints.maxHeight)
                                Positioned(
                                  top: chartHeight + 12,
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: _wallets(dates[selected]),
                                ),
                            ],
                          ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chart(List<int> balances, List<DateTime> dates) {
    final colors = context.coconutColors;
    final values = balances.sublist(_first, _last + 1);
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final selected = _selected;
    final localSelected = selected != null && selected >= _first && selected <= _last ? selected - _first : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(vm.data.unit.symbol, style: CoconutTypography.caption_10.copyWith(color: colors.tertiaryText)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  key: const Key('balance-history-value-axis'),
                  width: 46,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      mainAxisAlignment: minimum == maximum ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final amount in {
                          for (var tick = 4; tick >= 0; tick--) (minimum + (maximum - minimum) * tick / 4).round(),
                        })
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              vm.data.unit.displayBitcoinAmount(amount),
                              style: CoconutTypography.caption_10_Number.copyWith(color: colors.tertiaryText),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      return GestureDetector(
                        key: const Key('balance-history-interactive-chart'),
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          if (_selected == null) {
                            _focusAt(details.localPosition.dx, width);
                          } else {
                            setState(() {
                              _selected = null;
                              _expanded.clear();
                            });
                          }
                        },
                        onScaleStart: (details) {
                          _startSpan = _span;
                          _startEnd = _end;
                          _startPosition = details.localFocalPoint;
                          _pinching = details.pointerCount > 1;
                        },
                        onScaleUpdate: (details) {
                          if (details.pointerCount > 1) _pinching = true;
                          if (_selected != null && !_pinching) {
                            _focusAt(details.localFocalPoint.dx, width);
                            return;
                          }
                          if (_pinching && details.pointerCount < 2) return;
                          final delta = details.localFocalPoint - _startPosition;
                          final zoom =
                              _pinching
                                  ? details.scale
                                  : delta.dy.abs() > delta.dx.abs()
                                  ? math.exp(-delta.dy / 160)
                                  : 1.0;
                          final span = (_startSpan / zoom).clamp(2.0, _days.toDouble());
                          final anchor =
                              _selected?.toDouble() ?? _startEnd - (_startSpan - 1) * (1 - _startPosition.dx / width);
                          final fraction =
                              _selected == null
                                  ? _startPosition.dx / width
                                  : ((_selected! - (_startEnd - _startSpan + 1)) / (_startSpan - 1)).clamp(0.0, 1.0);
                          setState(() {
                            _span = span;
                            _end = (zoom == 1 && !_pinching
                                    ? _startEnd - delta.dx / width * (_startSpan - 1)
                                    : anchor + (span - 1) * (1 - fraction))
                                .clamp(span - 1, (_days - 1).toDouble());
                            _syncPeriod();
                          });
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(child: HomeSparkline(values: values, selectedIndex: localSelected)),
                            if (localSelected != null)
                              Builder(
                                builder: (context) {
                                  final point = HomeSparkline.pointOf(values, localSelected, constraints.biggest);
                                  return Positioned(
                                    top: -42,
                                    width: 150,
                                    left: (point.dx - 75).clamp(0.0, math.max(0.0, width - 150)),
                                    child: Container(
                                      key: const Key('hodl-insights-balance-readout'),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: colors.homeBackground,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          FittedBox(
                                            child: Text(
                                              vm.data.unit.displayBitcoinAmount(values[localSelected], withUnit: true),
                                              style: CoconutTypography.body3_12_NumberBold.copyWith(
                                                color: colors.primaryText,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            DateFormat('yyyy.MM.dd').format(dates[selected!]),
                                            style: CoconutTypography.caption_10_Number.copyWith(
                                              color: colors.tertiaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final index in {_first, (_first + _last) ~/ 2, _last})
                Text(
                  DateFormat('yy.MM.dd').format(dates[index]),
                  style: CoconutTypography.caption_10_Number.copyWith(color: colors.tertiaryText),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wallets(DateTime day) {
    final colors = context.coconutColors;
    final provider = context.read<WalletProvider>();
    final end = DateTime(day.year, day.month, day.day + 1);
    final states =
        [
          for (final wallet in vm.data.wallets)
            if (vm.walletIds == null || vm.walletIds!.contains(wallet.id))
              () {
                final all = provider.getTransactionRecordList(wallet.id);
                final today =
                    all.where((tx) => !tx.timestamp.isBefore(day) && tx.timestamp.isBefore(end)).toList()
                      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                return (
                  wallet: wallet,
                  transactions: today,
                  hasHistory: all.any((tx) => tx.timestamp.isBefore(end)),
                  balance:
                      vm.data.balanceOf(wallet.id) -
                      all.where((tx) => !tx.timestamp.isBefore(end)).fold<int>(0, (s, tx) => s + tx.amount),
                  change: today.fold<int>(0, (s, tx) => s + tx.amount),
                );
              }(),
        ].where((state) => state.hasHistory && (!_changedOnly || state.change != 0)).toList();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${t.wallet_list.balance_history_detail.wallets_at_date} · ${states.length}',
                style: CoconutTypography.body1_16_Bold.copyWith(color: colors.primaryText),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _changedOnly = !_changedOnly),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CoconutCheckbox(
                      isSelected: _changedOnly,
                      width: 14,
                      color: colors.iconPrimary,
                      unSelectedColor: colors.iconSecondary,
                      inactiveColor: colors.iconDisabled,
                      onChanged: (_) => setState(() => _changedOnly = !_changedOnly),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        t.wallet_list.balance_history_detail.changed_wallets_only,
                        textAlign: TextAlign.right,
                        style: CoconutTypography.caption_10.copyWith(color: colors.secondaryText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder:
                (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
            child:
                states.isEmpty
                    ? Center(
                      key: ValueKey(day),
                      child: Text(
                        t.wallet_list.balance_history_detail.no_wallets,
                        style: CoconutTypography.body2_14.copyWith(color: colors.secondaryText),
                      ),
                    )
                    : ListView.separated(
                      key: ValueKey((day, _changedOnly)),
                      padding: EdgeInsets.zero,
                      itemCount: states.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final state = states[index];
                        final expanded = _expanded.contains(state.wallet.id);
                        return Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            children: [
                              WalletItemCard(
                                walletItem: state.wallet,
                                animatedBalanceData: AnimatedBalanceData(state.balance, state.balance),
                                fakeBalance: state.balance,
                                currentUnit: vm.data.unit,
                                isLastItem: true,
                                isStarVisible: false,
                                backgroundColor: colors.homeSurface,
                                onPressed: () {
                                  if (state.transactions.isEmpty) return;
                                  setState(() {
                                    if (expanded) {
                                      _expanded.remove(state.wallet.id);
                                    } else {
                                      _expanded.add(state.wallet.id);
                                    }
                                  });
                                },
                                rightWidget: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (state.transactions.isNotEmpty) ...[
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${state.change > 0 ? '+' : ''}${vm.data.unit.displayBitcoinAmount(state.change, withUnit: true)}',
                                            style: CoconutTypography.body3_12_NumberBold.copyWith(
                                              color: homePriceColorOf(
                                                context,
                                                state.change.sign.toDouble(),
                                                neutral: colors.primaryText,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            t.wallet_list.balance_history_detail.transaction_count(
                                              n: state.transactions.length,
                                            ),
                                            style: CoconutTypography.caption_10.copyWith(color: colors.secondaryText),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      AnimatedRotation(
                                        turns: expanded ? 0.5 : 0,
                                        duration: const Duration(milliseconds: 220),
                                        child: Icon(Icons.expand_more, size: 18, color: colors.iconSecondary),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 280),
                                alignment: Alignment.topCenter,
                                child:
                                    expanded
                                        ? Column(
                                          children: [
                                            for (final tx in state.transactions)
                                              TransactionItemCard(
                                                tx: tx,
                                                id: state.wallet.id,
                                                currentUnit: vm.data.unit,
                                                compact: true,
                                                backgroundColor: colors.homeSurface,
                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                onPressed:
                                                    () => Navigator.pushNamed(
                                                      context,
                                                      AppRouteNames.transactionDetail,
                                                      arguments: TransactionDetailRouteArgs(
                                                        id: state.wallet.id,
                                                        txHash: tx.transactionHash,
                                                      ),
                                                    ),
                                              ),
                                          ],
                                        )
                                        : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ),
      ],
    );
  }
}
