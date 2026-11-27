import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutChip, CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/providers/view_model/home/hodl_insights_view_model.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_balance_history_screen.dart' show walletBalanceHistoryFlight;
import 'package:coconut_wallet/services/home/home_widget_math.dart';
import 'package:coconut_wallet/services/home/wallet_balance_detail_math.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_history_period_chips.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

/// 호들 인사이트의 '지갑별 잔액' 카드에서 열 때 쓰는 기본 Hero 태그.
/// 인사이트를 홈 위젯에서 열었으면 그 카드의 태그를 그대로 쓴다.
const balanceByWalletHeroTag = 'hodl-balance-by-wallet';

/// 지갑이 하나뿐일 때 '지갑을 더 추가하면 비중을 비교할 수 있어요' 안내를 보여 줄지.
/// 오케스트레이터가 최종 결정하므로 여기 한 곳만 바꾸면 된다.
const showAddWalletGuide = true;

const _plotHeight = 168.0;
const _axisWidth = 44.0;

/// 지갑별 잔액 상세: 지갑마다 잔액·비중·기간 변화를 본다.
/// 칩으로 지갑을 잠시 뺄 수 있고(마지막 한 개는 뺄 수 없다), 뺀 지갑은 도넛·추이·목록 계산에서 제외한다.
class BalanceByWalletScreen extends StatefulWidget {
  static const routeName = '/balance-by-wallet';

  final HodlInsightsViewModel viewModel;
  final Object heroTag;

  const BalanceByWalletScreen({super.key, required this.viewModel, this.heroTag = balanceByWalletHeroTag});

  /// 목표 수량과 같은 전환: 배경은 서서히 바뀌고 카드는 제자리에서 이어진다.
  static Future<void> open(
    BuildContext context,
    HodlInsightsViewModel viewModel, {
    Object heroTag = balanceByWalletHeroTag,
  }) => Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      settings: const RouteSettings(name: routeName),
      opaque: false,
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => BalanceByWalletScreen(viewModel: viewModel, heroTag: heroTag),
      transitionsBuilder:
          (_, animation, __, child) =>
              FadeTransition(opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)), child: child),
    ),
  );

  @override
  State<BalanceByWalletScreen> createState() => _BalanceByWalletScreenState();
}

class _BalanceByWalletScreenState extends State<BalanceByWalletScreen> {
  HomeWidgetPeriod _period = HomeWidgetPeriod.month;
  WalletBalanceSort _sort = WalletBalanceSort.balance;

  /// 칩을 눌러 뺀 지갑. 이 화면에 있는 동안만 유지한다.
  Set<int> _excluded = {};

  /// 차트를 길게 누른 날(기간 안 몇 번째 날). 누르고 있는 동안만 있다.
  int? _focused;

  HodlInsightsViewModel get vm => widget.viewModel;

  int get _days =>
      _period == HomeWidgetPeriod.all
          ? math.max(2, vm.data.daysSinceFirstTransaction(walletIds: vm.walletIds))
          : _period.days;

  List<WalletBalanceInput> _inputs(int days) {
    final data = vm.data;
    final scope = vm.walletIds;
    return [
      for (final wallet in data.wallets)
        if (scope == null || scope.contains(wallet.id))
          () {
            final isVault = wallet.walletImportSource == WalletImportSource.coconutVault;
            DateTime? first;
            for (final tx in data.transactionRecordsOf(wallet.id)) {
              if (first == null || tx.timestamp.isBefore(first)) first = tx.timestamp;
            }
            return WalletBalanceInput(
              walletId: wallet.id,
              name: wallet.name,
              balances: data.dailyBalances(walletIds: [wallet.id], days: days),
              firstTransactionAt: first,
              tags: WalletBalanceDetailMath.tagsOf(
                hasLocalKey: wallet.hasLocalKey,
                isVault: isVault,
                isMultisig: wallet.walletType == WalletType.multiSignature,
              ),
              colorIndex: isVault ? wallet.colorIndex : null,
            );
          }(),
    ];
  }

  void _toggle(int walletId, List<WalletBalanceInput> wallets) => setState(() {
    _excluded = WalletBalanceDetailMath.toggleExcluded(_excluded, walletId, [for (final w in wallets) w.walletId]);
    _focused = null;
  });

  void _openWallet(int walletId) =>
      Navigator.of(context).pushNamed(AppRouteNames.walletDetail, arguments: WalletDetailRouteArgs(id: walletId));

  String _number(int sats) => vm.data.unit.displayBitcoinAmount(sats);
  String _text(int sats) => vm.data.unit.displayBitcoinAmount(sats, withUnit: true);
  HomeAmount _amount(int sats) =>
      HomeAmount(_number(sats), vm.data.unit.symbol, unitFirst: vm.data.unit.isPrefixSymbol);

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final days = _days;
        final dates = HomeWidgetMath.lastDays(vm.data.now, days);
        final wallets = _inputs(days);
        final existing = {for (final wallet in wallets) wallet.walletId};
        // 삭제된 지갑·전부 제외된 상태를 바로잡아 칩·안내·집계가 같은 지갑을 가리키게 한다.
        final excluded = WalletBalanceDetailMath.normalizeExcluded(_excluded, existing);
        final breakdown = WalletBalanceDetailMath.compose(
          wallets: wallets,
          excluded: excluded,
          days: dates,
          sort: _sort,
        );
        if (wallets.isEmpty) {
          return Scaffold(
            backgroundColor: colors.homeBackground,
            appBar: CoconutAppBar.build(
              context: context,
              backgroundColor: colors.homeBackground,
              title: t.home_widgets.balance_by_wallet,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  t.balance_by_wallet_screen.empty_wallets,
                  key: const Key('balance-by-wallet-empty'),
                  textAlign: TextAlign.center,
                  style: CoconutTypography.body2_14.copyWith(color: colors.tertiaryText),
                ),
              ),
            ),
          );
        }
        final focused = _focused != null && _focused! < dates.length ? _focused : null;
        return Scaffold(
          backgroundColor: colors.homeBackground,
          appBar: CoconutAppBar.build(
            context: context,
            backgroundColor: colors.homeBackground,
            title: t.home_widgets.balance_by_wallet,
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              key: const Key('balance-by-wallet-list'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                if (wallets.length > 1) ...[
                  _WalletChips(wallets: wallets, excluded: excluded, onToggle: (id) => _toggle(id, wallets)),
                  CoconutLayout.spacing_400h,
                ] else if (showAddWalletGuide && wallets.length == 1) ...[
                  const _AddWalletGuide(),
                  CoconutLayout.spacing_400h,
                ],
                Hero(
                  tag: widget.heroTag,
                  flightShuttleBuilder: walletBalanceHistoryFlight,
                  child: Material(
                    key: const Key('balance-by-wallet-summary'),
                    color: colors.homeSurface,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _SummaryCard(
                        breakdown: breakdown,
                        totalWallets: wallets.length,
                        excludedCount: excluded.length,
                        period: _period,
                        amount: _amount,
                        text: _text,
                        onPeriod:
                            (period) => setState(() {
                              _period = period;
                              _focused = null;
                            }),
                      ),
                    ),
                  ),
                ),
                CoconutLayout.spacing_400h,
                _TrendCard(
                  breakdown: breakdown,
                  dates: dates,
                  focused: focused,
                  number: _number,
                  text: _text,
                  unitLabel: vm.data.unit.symbol,
                  onFocus: (index) => setState(() => _focused = index),
                ),
                if (excluded.isNotEmpty) ...[
                  CoconutLayout.spacing_300h,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      key: const Key('balance-by-wallet-scope'),
                      t.balance_by_wallet_screen.excluded_scope(
                        names: [
                          for (final wallet in wallets)
                            if (excluded.contains(wallet.walletId)) wallet.name,
                        ].join(', '),
                      ),
                      style: CoconutTypography.body3_12.copyWith(color: colors.tertiaryText),
                    ),
                  ),
                ],
                CoconutLayout.spacing_400h,
                _WalletListCard(
                  breakdown: breakdown,
                  sort: _sort,
                  onSort: (sort) => setState(() => _sort = sort),
                  amount: _amount,
                  text: _text,
                  onOpen: _openWallet,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 지갑이 하나뿐일 때 비교 안내
class _AddWalletGuide extends StatelessWidget {
  const _AddWalletGuide();

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      key: const Key('balance-by-wallet-guide'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(12)),
      child: Text(
        t.balance_by_wallet_screen.add_wallet_guide,
        textAlign: TextAlign.center,
        style: CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong),
      ),
    );
  }
}

/// 지갑 칩. 눌러서 잠시 빼거나 다시 넣는다.
class _WalletChips extends StatelessWidget {
  final List<WalletBalanceInput> wallets;
  final Set<int> excluded;
  final ValueChanged<int> onToggle;

  const _WalletChips({required this.wallets, required this.excluded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final appearances = context.watchWalletAppearance();
    return Wrap(
      key: const Key('balance-by-wallet-chips'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final wallet in wallets)
          Builder(
            builder: (context) {
              final active = !excluded.contains(wallet.walletId);
              final walletColor = BalanceByWalletView.colorOf(context, _shareOf(wallet), appearances: appearances);
              return CoconutChip(
                key: ValueKey('balance-by-wallet-chip-${wallet.walletId}'),
                color: colors.homeSurface,
                borderColor: active ? walletColor : colors.border,
                labelColor: active ? colors.primaryText : colors.tertiaryText,
                label: wallet.name,
                labelSize: 13,
                isSelected: active,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                onTap: () => onToggle(wallet.walletId),
              );
            },
          ),
      ],
    );
  }
}

HomeBalanceShare _shareOf(WalletBalanceInput wallet) => HomeBalanceShare(
  walletId: wallet.walletId,
  name: wallet.name,
  balance: wallet.current,
  colorIndex: wallet.colorIndex,
);

String _tagLabel(WalletKindTag tag) => switch (tag) {
  WalletKindTag.hot => t.balance_by_wallet_screen.tag_hot,
  WalletKindTag.watchOnly => t.balance_by_wallet_screen.tag_watch_only,
  WalletKindTag.vault => t.balance_by_wallet_screen.tag_vault,
  WalletKindTag.multisig => t.balance_by_wallet_screen.tag_multisig,
};

String _signedText(int sats, String Function(int sats) text) => '${sats >= 0 ? '+' : '-'} ${text(sats.abs())}';

/// 상단 요약. Hero로 이어지는 카드 안쪽이며 기간 칩까지 포함한다.
/// 요약 카드에서 범례에 남겨 둘 최소 가로 폭과 도넛 최소 지름
const double _legendMinWidth = 140;
const double _donutMinDiameter = 72;

class _SummaryCard extends StatelessWidget {
  final WalletBalanceBreakdown breakdown;
  final int totalWallets;
  final int excludedCount;
  final HomeWidgetPeriod period;
  final HomeAmount Function(int sats) amount;
  final String Function(int sats) text;
  final ValueChanged<HomeWidgetPeriod> onPeriod;

  const _SummaryCard({
    required this.breakdown,
    required this.totalWallets,
    required this.excludedCount,
    required this.period,
    required this.amount,
    required this.text,
    required this.onPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final single = breakdown.isSingle;
    final strings = t.balance_by_wallet_screen;
    final only = breakdown.rows.first.input;
    final title =
        single
            ? only.name
            : excludedCount == 0
            ? strings.all_wallets_balance
            : strings.selected_wallets_balance;
    final sub =
        single
            ? only.tags.map(_tagLabel).join(' · ')
            : excludedCount == 0
            ? strings.wallet_count(count: totalWallets)
            : strings.selected_count(selected: totalWallets - excludedCount, total: totalWallets);
    // 도넛·범례는 목록 정렬과 무관하게 잔액 순으로 고정한다.
    final donutShares = [for (final row in breakdown.balanceRows) _shareOf(row.input)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CoconutTypography.body1_16_Bold.copyWith(color: colors.primaryText),
              ),
            ),
            if (sub.isNotEmpty) ...[
              CoconutLayout.spacing_200w,
              Text(sub, style: CoconutTypography.body3_12.copyWith(color: colors.tertiaryText)),
            ],
          ],
        ),
        CoconutLayout.spacing_300h,
        HomeAmountText(
          key: const Key('balance-by-wallet-total'),
          amount: amount(breakdown.total),
          numberStyle: CoconutTypography.heading3_21_NumberBold.copyWith(color: colors.primaryText),
          unitStyle: CoconutTypography.body2_14.copyWith(color: colors.primaryText),
        ),
        CoconutLayout.spacing_200h,
        Row(
          children: [
            Text(
              _signedText(breakdown.change, text),
              key: const Key('balance-by-wallet-change'),
              style: CoconutTypography.body3_12_Number.copyWith(color: colors.secondaryText),
            ),
            CoconutLayout.spacing_200w,
            Text(
              strings.period_change(period: homePeriodLabel(period)),
              style: CoconutTypography.body3_12.copyWith(color: colors.tertiaryText),
            ),
          ],
        ),
        if (!single) ...[
          CoconutLayout.spacing_400h,
          LayoutBuilder(
            builder: (context, constraints) {
              // 카드 안쪽 여백 32 + 도넛·범례 간격 16을 뺀 폭에서 범례 최소 폭을 남기고 도넛 지름을 제한한다.
              final maxDonut = (constraints.maxWidth - 32 - 16 - _legendMinWidth).clamp(
                _donutMinDiameter,
                double.infinity,
              );
              return SizedBox(
                key: const Key('balance-by-wallet-donut'),
                // 지갑이 많으면 범례가 모두 보이도록 카드 높이가 지갑 수만큼 늘어난다.
                height: math.max(160.0, 34.0 * donutShares.length),
                // 도넛과 범례는 홈의 '지갑별 잔액'과 같은 위젯이다. 바탕이 같아 카드 안에서 구분되지 않는다.
                child: BalanceByWalletView(
                  shares: donutShares,
                  total: amount(breakdown.total),
                  amountText: (sats) => amount(sats).number,
                  maxDonutDiameter: maxDonut,
                ),
              );
            },
          ),
        ],
        CoconutLayout.spacing_400h,
        Align(
          alignment: Alignment.centerLeft,
          child: BalanceHistoryPeriodChips(selected: period, onSelected: onPeriod),
        ),
      ],
    );
  }
}

/// 비중 추이(여러 지갑) 또는 잔액 변화(단일 지갑)
class _TrendCard extends StatelessWidget {
  final WalletBalanceBreakdown breakdown;
  final List<DateTime> dates;
  final int? focused;
  final String Function(int sats) number;
  final String Function(int sats) text;
  final String unitLabel;
  final ValueChanged<int?> onFocus;

  const _TrendCard({
    required this.breakdown,
    required this.dates,
    required this.focused,
    required this.number,
    required this.text,
    required this.unitLabel,
    required this.onFocus,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final strings = t.balance_by_wallet_screen;
    final single = breakdown.isSingle;
    final appearances = context.watchWalletAppearance();
    final dateFormat = DateFormat('yyyy.MM.dd');
    final axisStyle = CoconutTypography.caption_10_Number.copyWith(color: colors.tertiaryText);
    final last = dates.length - 1;

    // 그리는 층: 아래 경계와 위 경계(0~1), 색.
    final layers = <_Layer>[];
    var axisLabels = const ['100%', '50%', '0%'];
    if (single) {
      final values = breakdown.totals;
      final range = HomeWidgetMath.balanceAxisRange(values.reduce(math.min), values.reduce(math.max));
      final span = (range.maximum - range.minimum).toDouble();
      layers.add(
        _Layer(
          lower: List.filled(values.length, 0),
          upper: [for (final value in values) span <= 0 ? 0 : (value - range.minimum) / span],
          color: BalanceByWalletView.colorOf(context, _shareOf(breakdown.rows.first.input), appearances: appearances),
        ),
      );
      axisLabels = [number(range.maximum), number((range.minimum + range.maximum) ~/ 2), number(range.minimum)];
    } else {
      var lower = List<double>.filled(dates.length, 0);
      for (var i = 0; i < breakdown.stack.length; i++) {
        final wallet = breakdown.stack[i];
        final upper = [
          for (var d = 0; d < dates.length; d++)
            lower[d] + WalletBalanceDetailMath.shareOf(wallet.balances[d], breakdown.totals[d]),
        ];
        layers.add(
          _Layer(
            lower: lower,
            upper: upper,
            color: BalanceByWalletView.colorOf(context, _shareOf(wallet), appearances: appearances),
            // 맨 위 층의 위 경계는 100% 선이므로 경계선을 긋지 않는다.
            border: i < breakdown.stack.length - 1,
          ),
        );
        lower = upper;
      }
    }

    final tooltipColor = Theme.of(context).brightness == Brightness.dark ? colors.surface : colors.surfaceMuted;
    return Container(
      key: const Key('balance-by-wallet-trend'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  single ? strings.balance_trend : strings.share_trend,
                  style: CoconutTypography.body1_16_Bold.copyWith(color: colors.primaryText),
                ),
              ),
              Text(
                single ? unitLabel : strings.selected_basis,
                style: CoconutTypography.body3_12.copyWith(color: colors.tertiaryText),
              ),
            ],
          ),
          CoconutLayout.spacing_100h,
          Text(
            '${dateFormat.format(dates.first)} — ${DateFormat('MM.dd').format(dates.last)}',
            style: CoconutTypography.body3_12_Number.copyWith(color: colors.secondaryTextStrong),
          ),
          CoconutLayout.spacing_300h,
          LayoutBuilder(
            builder: (context, constraints) {
              final plotWidth = math.max(1.0, constraints.maxWidth - _axisWidth);
              double xOf(int index) => last <= 0 ? 0 : plotWidth * index / last;
              const tooltipWidth = 176.0;
              return Column(
                children: [
                  SizedBox(
                    height: _plotHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: _axisWidth,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [for (final label in axisLabels) Text(label, style: axisStyle, maxLines: 1)],
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: GestureDetector(
                                  key: const Key('balance-by-wallet-plot'),
                                  behavior: HitTestBehavior.opaque,
                                  onLongPressStart:
                                      (details) => onFocus(_indexAt(details.localPosition.dx, plotWidth, dates.length)),
                                  onLongPressMoveUpdate:
                                      (details) => onFocus(_indexAt(details.localPosition.dx, plotWidth, dates.length)),
                                  onLongPressEnd: (_) => onFocus(null),
                                  onLongPressCancel: () => onFocus(null),
                                  child: CustomPaint(
                                    painter: _TrendPainter(
                                      layers: layers,
                                      gridColor: colors.border,
                                      lineColor: colors.secondaryTextStrong,
                                      borderColor: colors.homeSurface,
                                      focused: focused,
                                    ),
                                  ),
                                ),
                              ),
                              if (focused != null)
                                Positioned(
                                  left: (xOf(focused!) - tooltipWidth / 2).clamp(
                                    0.0,
                                    math.max(0.0, plotWidth - tooltipWidth),
                                  ),
                                  top: 0,
                                  width: tooltipWidth,
                                  child: IgnorePointer(
                                    child: _Tooltip(
                                      key: const Key('balance-by-wallet-tooltip'),
                                      color: tooltipColor,
                                      date: dateFormat.format(dates[focused!]),
                                      breakdown: breakdown,
                                      day: focused!,
                                      text: text,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  CoconutLayout.spacing_100h,
                  Padding(
                    padding: const EdgeInsets.only(left: _axisWidth),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final index in {0, last ~/ 2, last})
                          Text(DateFormat('M/d').format(dates[index]), style: axisStyle),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          CoconutLayout.spacing_200h,
          Text(
            focused == null ? strings.long_press_hint : dateFormat.format(dates[focused!]),
            style: CoconutTypography.body3_12.copyWith(color: colors.tertiaryText),
          ),
        ],
      ),
    );
  }

  static int _indexAt(double x, double width, int count) =>
      count <= 1 ? 0 : (x / width * (count - 1)).round().clamp(0, count - 1);
}

class _Layer {
  final List<double> lower;
  final List<double> upper;
  final Color color;

  /// 위 경계에 구분선을 그릴지. 같은 색 지갑이 맞닿아도 나뉘어 보이게 한다.
  final bool border;

  const _Layer({required this.lower, required this.upper, required this.color, this.border = false});
}

class _TrendPainter extends CustomPainter {
  final List<_Layer> layers;
  final Color gridColor;
  final Color lineColor;
  final Color borderColor;
  final int? focused;

  _TrendPainter({
    required this.layers,
    required this.gridColor,
    required this.lineColor,
    required this.borderColor,
    required this.focused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final grid =
        Paint()
          ..color = gridColor
          ..strokeWidth = 0.5;
    for (final fraction in const [0.0, 0.5, 1.0]) {
      final y = size.height * (1 - fraction);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (final layer in layers) {
      final count = layer.upper.length;
      if (count == 0) continue;
      double x(int i) => count <= 1 ? 0 : size.width * i / (count - 1);
      double y(double value) => size.height * (1 - value.clamp(0.0, 1.0));
      final path = Path()..moveTo(x(0), y(layer.upper[0]));
      for (var i = 1; i < count; i++) {
        path.lineTo(x(i), y(layer.upper[i]));
      }
      for (var i = count - 1; i >= 0; i--) {
        path.lineTo(x(i), y(layer.lower[i]));
      }
      path.close();
      canvas.drawPath(path, Paint()..color = layer.color);
      if (layer.border) {
        final edge = Path()..moveTo(x(0), y(layer.upper[0]));
        for (var i = 1; i < count; i++) {
          edge.lineTo(x(i), y(layer.upper[i]));
        }
        canvas.drawPath(
          edge,
          Paint()
            ..color = borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }
    final index = focused;
    if (index != null && layers.isNotEmpty) {
      final count = layers.first.upper.length;
      final fx = count <= 1 ? 0.0 : size.width * index / (count - 1);
      canvas.drawLine(
        Offset(fx, 0),
        Offset(fx, size.height),
        Paint()
          ..color = lineColor
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.focused != focused ||
      old.gridColor != gridColor ||
      old.lineColor != lineColor ||
      old.borderColor != borderColor ||
      old.layers != layers;
}

/// 길게 누른 날의 지갑별 잔액과 비중
class _Tooltip extends StatelessWidget {
  final Color color;
  final String date;
  final WalletBalanceBreakdown breakdown;
  final int day;
  final String Function(int sats) text;

  const _Tooltip({
    super.key,
    required this.color,
    required this.date,
    required this.breakdown,
    required this.day,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final appearances = context.watchWalletAppearance();
    final shares = breakdown.sharesAt(day);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(date, style: CoconutTypography.caption_10_Number.copyWith(color: colors.tertiaryText)),
              ),
              Text(
                text(breakdown.totals[day]),
                style: CoconutTypography.caption_10_NumberBold.copyWith(color: colors.primaryText),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (breakdown.isSingle)
            const SizedBox.shrink()
          else
            for (var i = 0; i < breakdown.stack.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: BalanceByWalletView.colorOf(
                          context,
                          _shareOf(breakdown.stack[i]),
                          appearances: appearances,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        breakdown.stack[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CoconutTypography.caption_10.copyWith(color: colors.primaryText),
                      ),
                    ),
                    Text(
                      '${text(breakdown.stack[i].balances[day])} · ${(shares[i] * 100).toStringAsFixed(1)}%',
                      style: CoconutTypography.caption_10_Number.copyWith(color: colors.secondaryTextStrong),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// 지갑 목록. 정렬을 바꾸고, 줄을 누르면 그 지갑 상세로 간다.
class _WalletListCard extends StatelessWidget {
  final WalletBalanceBreakdown breakdown;
  final WalletBalanceSort sort;
  final ValueChanged<WalletBalanceSort> onSort;
  final HomeAmount Function(int sats) amount;
  final String Function(int sats) text;
  final ValueChanged<int> onOpen;

  const _WalletListCard({
    required this.breakdown,
    required this.sort,
    required this.onSort,
    required this.amount,
    required this.text,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final strings = t.balance_by_wallet_screen;
    final appearances = context.watchWalletAppearance();
    final dateFormat = DateFormat('M/d');
    return Container(
      key: const Key('balance-by-wallet-list-card'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(strings.wallet_list, style: CoconutTypography.body1_16_Bold.copyWith(color: colors.primaryText)),
              CoconutLayout.spacing_200w,
              Text(
                strings.wallet_list_count(count: breakdown.rows.length),
                style: CoconutTypography.body3_12.copyWith(color: colors.tertiaryText),
              ),
            ],
          ),
          if (breakdown.rows.length > 1) ...[
            CoconutLayout.spacing_300h,
            Align(
              alignment: Alignment.centerLeft,
              child: _SortChips(
                selected: sort == WalletBalanceSort.balance ? 0 : 1,
                items: [
                  (key: const Key('balance-by-wallet-sort-balance'), label: strings.sort_balance),
                  (key: const Key('balance-by-wallet-sort-change'), label: strings.sort_change),
                ],
                onSelected: (index) => onSort(index == 0 ? WalletBalanceSort.balance : WalletBalanceSort.change),
              ),
            ),
          ],
          CoconutLayout.spacing_200h,
          for (var i = 0; i < breakdown.rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 0.5, color: colors.border),
            Builder(
              builder: (context) {
                final row = breakdown.rows[i];
                final tags = row.input.tags.map(_tagLabel).join(' · ');
                final dot = BalanceByWalletView.colorOf(context, _shareOf(row.input), appearances: appearances);
                return GestureDetector(
                  key: ValueKey('balance-by-wallet-row-${row.walletId}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onOpen(row.walletId),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                row.input.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CoconutTypography.body2_14_Bold.copyWith(color: colors.primaryText),
                              ),
                            ),
                            Text(
                              '${(row.share * 100).toStringAsFixed(1)}%',
                              style: CoconutTypography.body2_14_NumberBold.copyWith(color: colors.primaryText),
                            ),
                            Icon(Icons.chevron_right, size: 16, color: colors.tertiaryText),
                          ],
                        ),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(tags, style: CoconutTypography.caption_10.copyWith(color: colors.tertiaryText)),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                text(row.balance),
                                style: CoconutTypography.body3_12_Number.copyWith(color: colors.secondaryTextStrong),
                              ),
                            ),
                            Text(
                              _signedText(row.change, text),
                              key: ValueKey('balance-by-wallet-row-change-${row.walletId}'),
                              style: CoconutTypography.body3_12_Number.copyWith(color: colors.secondaryText),
                            ),
                          ],
                        ),
                        if (row.firstActiveDay != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            strings.first_transaction(date: dateFormat.format(row.firstActiveDay!)),
                            style: CoconutTypography.caption_10.copyWith(color: colors.tertiaryText),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// 정렬 칩. 모양·동작은 [BalanceHistoryPeriodChips]와 같고(묶음 막대 + 선택 칸 슬라이드),
/// 칸 크기만 이전 정렬 버튼과 같게 키웠다. 기간 칩 위젯은 다른 화면이 쓰므로 건드리지 않고 이 화면에 둔다.
class _SortChips extends StatelessWidget {
  final int selected;
  final List<({Key key, String label})> items;
  final ValueChanged<int> onSelected;

  const _SortChips({required this.selected, required this.items, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: colors.homeBackground, borderRadius: BorderRadius.circular(10)),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: selected.toDouble()),
        duration:
            MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder:
            (context, position, child) =>
                _SortChipBackground(position: position, selectedColor: colors.primaryText, child: child!),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++)
              GestureDetector(
                key: items[i].key,
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    items[i].label,
                    style: CoconutTypography.body3_12.copyWith(
                      color: i == selected ? colors.background : colors.tertiaryText,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SortChipBackground extends SingleChildRenderObjectWidget {
  final double position;
  final Color selectedColor;

  const _SortChipBackground({required this.position, required this.selectedColor, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSortChipBackground(position, selectedColor);

  @override
  void updateRenderObject(BuildContext context, _RenderSortChipBackground renderObject) {
    renderObject
      ..position = position
      ..selectedColor = selectedColor
      ..markNeedsPaint();
  }
}

class _RenderSortChipBackground extends RenderProxyBox {
  double position;
  Color selectedColor;

  _RenderSortChipBackground(this.position, this.selectedColor);

  @override
  void paint(PaintingContext context, Offset offset) {
    final row = child! as RenderFlex;
    final rects = <Rect>[];
    for (RenderBox? chip = row.firstChild; chip != null; chip = row.childAfter(chip)) {
      rects.add((chip.parentData! as FlexParentData).offset & chip.size);
    }
    final value = position.clamp(0.0, rects.length - 1.0);
    final selectedRect = Rect.lerp(rects[value.floor()], rects[value.ceil()], value - value.floor())!;
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(selectedRect.shift(offset), const Radius.circular(8)),
      Paint()..color = selectedColor,
    );
    super.paint(context, offset);
  }
}
