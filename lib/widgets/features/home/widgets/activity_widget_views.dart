import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/utils/legible_color_util.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/widgets/common/icon/transaction_status_gradient_mask.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/cupertino.dart';

/// 4×2: 최근 24시간 거래 목록
/// 4×2: 가장 최근 거래 세 건. 거래가 모자라면 남은 줄 자리를 비워 두고 안내 문구를 둔다.
class RecentTransactionsView extends StatelessWidget {
  static const rows = 3;

  final List<HomeRecentTransaction> transactions;
  final String Function(int sats) amountText;
  final DateTime now;
  final void Function(int walletId)? onTransactionTap;

  const RecentTransactionsView({
    super.key,
    required this.transactions,
    required this.amountText,
    required this.now,
    this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    if (transactions.isEmpty) {
      return HomeWidgetCard(
        key: const Key('recent-transactions-empty'),
        child: Center(
          child: Text(
            t.home_widgets.no_recent_transactions,
            textAlign: TextAlign.center,
            style: CoconutTypography.body3_12.copyWith(color: colors.secondaryText),
          ),
        ),
      );
    }
    final shown = transactions.take(rows).toList();
    final emptyRows = rows - shown.length;
    Widget divider() => Container(margin: const EdgeInsets.symmetric(horizontal: 12), height: 1, color: colors.divider);
    return HomeWidgetCard(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rowHeight = (constraints.maxHeight - (rows - 1)) / rows;
          return Column(
            key: const Key('recent-transactions-list'),
            children: [
              for (final (index, tx) in shown.indexed) ...[
                if (index > 0) divider(),
                _TransactionRow(
                  key: ValueKey('recent-transactions-row-$index'),
                  tx: tx,
                  amountText: amountText,
                  now: now,
                  height: rowHeight,
                  onTap: onTransactionTap == null ? null : () => onTransactionTap!(tx.walletId),
                ),
              ],
              if (emptyRows > 0) ...[
                divider(),
                SizedBox(
                  key: const Key('recent-transactions-waiting'),
                  height: rowHeight * emptyRows + (emptyRows - 1),
                  child: Center(
                    child: Text(
                      t.home_widgets.waiting_for_transactions,
                      textAlign: TextAlign.center,
                      style: CoconutTypography.body3_12.copyWith(color: colors.tertiaryText),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final HomeRecentTransaction tx;
  final String Function(int sats) amountText;
  final DateTime now;
  final double height;
  final VoidCallback? onTap;

  const _TransactionRow({
    super.key,
    required this.tx,
    required this.amountText,
    required this.now,
    required this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final sign = tx.amount >= 0 ? '+' : '-';
    final status =
        tx.status ??
        switch (tx.type) {
          TransactionType.received => TransactionStatus.received,
          TransactionType.sent => TransactionStatus.sent,
          _ => TransactionStatus.self,
        };
    final row = SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            TransactionStatusGradientMask(
              enabled: status == TransactionStatus.self || status == TransactionStatus.selfsending,
              child: SvgPicture.asset(
                TransactionUtil.getStatusIconAsset(status),
                key: ValueKey('recent-transactions-icon-${status.name}'),
                fit: BoxFit.fill,
                width: 30,
                height: 30,
                colorFilter: ColorFilter.mode(switch (status) {
                  TransactionStatus.sent || TransactionStatus.sending => colors.sendingColor,
                  TransactionStatus.received || TransactionStatus.receiving => colors.receivingColor,
                  _ => colors.iconPrimary,
                }, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$sign ${amountText(tx.amount.abs())}',
                            style: CoconutTypography.body2_14_NumberBold.copyWith(color: colors.primaryText),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatHomeDateTime(tx.time, now),
                        style: CoconutTypography.caption_10_Number.copyWith(color: colors.tertiaryText),
                      ),
                    ],
                  ),
                  Text(
                    tx.walletName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoconutTypography.caption_10.copyWith(color: colors.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return _PressableRow(onTap: onTap!, child: row);
  }
}

/// 누르는 동안 홈 위젯과 같은 눌림 색을 깔고 살짝 줄어든다. 크기는 바꾸지 않는다.
class _PressableRow extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _PressableRow({required this.onTap, required this.child});

  @override
  State<_PressableRow> createState() => _PressableRowState();
}

class _PressableRowState extends State<_PressableRow> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color:
                _pressed
                    ? colors.homeSurfacePressOverlay.withValues(alpha: colors.homeSurfacePressOverlayOpacity)
                    : colors.homeSurfacePressOverlay.withValues(alpha: 0),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 4×2: 일별 받기·보내기·정리 횟수
class TransactionActivityView extends StatelessWidget {
  final List<HomeDailyActivity> days;
  final DateTime? rangeEnd;

  /// 막대 하나가 한 달이면 날짜 대신 달 이름을 쓴다.
  final bool monthly;

  /// 받기·보내기·정리 칸의 건수 아래에 붙이는 수량. 없으면 건수만 보인다.
  final List<String>? amountTexts;

  /// 호들 인사이트용: 기간 글자 없이, 막대는 카드 없이 그리고 요약만 카드에 담는다.
  final bool detailed;

  const TransactionActivityView({
    super.key,
    required this.days,
    this.rangeEnd,
    this.monthly = false,
    this.amountTexts,
    this.detailed = false,
  });

  static const double detailedChartHeight = 120;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final received = days.fold<int>(0, (sum, day) => sum + day.received);
    final sent = days.fold<int>(0, (sum, day) => sum + day.sent);
    final organized = days.fold<int>(0, (sum, day) => sum + day.organized);
    final maxCount = math.max(
      1,
      days
          .map((day) => math.max(day.received, math.max(day.sent, day.organized)))
          .fold<int>(0, (a, b) => math.max(a, b)),
    );
    final range =
        days.isEmpty
            ? ''
            : '${formatHomeShortDate(days.first.day)} ~ ${formatHomeShortDate(rangeEnd ?? days.last.day)}';
    final receivedColor = colors.receivingColor;
    final sentColor = colors.sendingColor;
    final organizedColor = colors.iconDisabled;
    final isEmpty = received + sent + organized == 0;
    Widget barsRow() => Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (index, day) in days.indexed)
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    key: ValueKey('transaction-activity-bars-$index'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Bar(count: day.received, max: maxCount, color: receivedColor),
                      _Bar(count: day.sent, max: maxCount, color: sentColor),
                      _Bar(count: day.organized, max: maxCount, color: organizedColor),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    monthly ? formatHomeMonth(day.day) : formatHomeShortDate(day.day),
                    maxLines: 1,
                    style: CoconutTypography.caption_10_Number.copyWith(color: colors.tertiaryText),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    Widget legend() => IntrinsicHeight(
      key: const Key('transaction-activity-legend'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Legend(color: receivedColor, label: t.home_widgets.received, count: received, amount: amountTexts?[0]),
          Container(key: const ValueKey('transaction-activity-legend-divider-0'), width: 1, color: colors.divider),
          _Legend(color: sentColor, label: t.home_widgets.sent, count: sent, amount: amountTexts?[1]),
          Container(key: const ValueKey('transaction-activity-legend-divider-1'), width: 1, color: colors.divider),
          _Legend(color: organizedColor, label: t.home_widgets.organized, count: organized, amount: amountTexts?[2]),
        ],
      ),
    );
    if (detailed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            key: const Key('transaction-activity-chart'),
            height: detailedChartHeight,
            child:
                isEmpty
                    ? Center(
                      child: Text(
                        t.home_widgets.no_period_transactions,
                        textAlign: TextAlign.center,
                        style: CoconutTypography.body3_12.copyWith(color: colors.secondaryText),
                      ),
                    )
                    : barsRow(),
          ),
          const SizedBox(height: 16),
          Container(
            key: const Key('transaction-activity-summary'),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(20)),
            child: legend(),
          ),
        ],
      );
    }
    if (isEmpty) {
      return HomeWidgetCard(
        key: const Key('transaction-activity-empty'),
        child: Column(
          children: [
            SizedBox(
              height: kHomeWidgetHeaderHeight,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(range, style: CoconutTypography.caption_10_Number.copyWith(color: colors.tertiaryText)),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  t.home_widgets.no_period_transactions,
                  textAlign: TextAlign.center,
                  style: CoconutTypography.body3_12.copyWith(color: colors.secondaryText),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return HomeWidgetCard(
      child: Column(
        children: [
          SizedBox(
            height: kHomeWidgetHeaderHeight,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(range, style: CoconutTypography.caption_10_Number.copyWith(color: colors.tertiaryText)),
            ),
          ),
          Expanded(child: barsRow()),
          const SizedBox(height: 8),
          legend(),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  static const double _width = 4;
  static const double _margin = 1;

  final int count;
  final int max;
  final Color color;

  const _Bar({required this.count, required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder:
          (context, constraints) => Container(
            width: _width,
            margin: const EdgeInsets.symmetric(horizontal: _margin),
            height: count == 0 ? 0 : math.max(2, constraints.maxHeight * count / max),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final String? amount;

  const _Legend({required this.color, required this.label, required this.count, this.amount});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CoconutTypography.caption_10.copyWith(color: colors.secondaryText),
                ),
              ),
            ],
          ),
          Text('$count', style: CoconutTypography.body1_16_NumberBold.copyWith(color: colors.primaryText)),
          if (amount != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                amount!,
                maxLines: 1,
                style: CoconutTypography.caption_10_Number.copyWith(color: colors.secondaryText),
              ),
            ),
        ],
      ),
    );
  }
}

/// 2×2: 목표 수량 대비 잔액
class SavingsGoalView extends StatelessWidget {
  final HomeSavingsGoal? goal;
  final String Function(int sats) amountText;

  const SavingsGoalView({super.key, required this.goal, required this.amountText});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final goal = this.goal;
    return HomeWidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeWidgetHeader(
            iconPath: FeatureWidgetIconPath.bullseyeArrow,
            iconKey: const Key('savings-goal-icon'),
            title: t.home_widgets.savings_goal,
            style: CoconutTypography.body3_12_Bold,
          ),
          const SizedBox(height: 8),
          if (goal == null)
            Expanded(
              key: const Key('savings-goal-empty'),
              child: Center(
                child: Text(
                  t.home_widgets.no_savings_goal,
                  textAlign: TextAlign.center,
                  style: CoconutTypography.caption_10.copyWith(color: colors.secondaryText),
                ),
              ),
            )
          else ...[
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${amountText(goal.balance)}\n/ ${amountText(goal.target)}',
                    style: CoconutTypography.body2_14_NumberBold.copyWith(color: colors.primaryText),
                  ),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(color: colors.surfaceMuted),
                    FractionallySizedBox(
                      key: const Key('goal-progress-fill'),
                      widthFactor: goal.progress,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: colors.success, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(goal.progress * 100).toStringAsFixed(1)}%',
              style: CoconutTypography.caption_10_NumberBold.copyWith(color: colors.primaryText),
            ),
          ],
        ],
      ),
    );
  }
}

/// 2×2: UTXO 개수와 금액 구간 분포
class UtxoStatusView extends StatelessWidget {
  static const bucketLabels = ['≥ 0.1', '0.01 ~ 0.1', '0.001 ~ 0.01', '< 0.001'];

  final HomeUtxoBuckets buckets;
  final List<Color> bucketColors;

  const UtxoStatusView({super.key, required this.buckets, required this.bucketColors});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final total = buckets.total;
    const tabular = [FontFeature.tabularFigures()];
    return HomeWidgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeWidgetHeader(
            iconPath: FeatureWidgetIconPath.coinStack,
            iconKey: const Key('utxo-status-icon'),
            title: t.home_widgets.utxo_count(count: total),
            style: CoconutTypography.body2_14_Bold,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const dotSize = 8.0;
                const dotGap = 8.0;
                const columnGap = 8.0;
                final labelStyle = CoconutTypography.caption_10.copyWith(
                  color: colors.secondaryText,
                  fontFeatures: tabular,
                );
                final countStyle = CoconutTypography.body3_12.copyWith(
                  color: colors.primaryText,
                  fontFeatures: tabular,
                );
                final counts = [
                  for (var i = 0; i < bucketLabels.length; i++)
                    '${buckets.counts[i]} (${total == 0 ? 0 : (buckets.counts[i] * 100 / total).toStringAsFixed(1)}%)',
                ];
                double widest(List<String> texts, TextStyle style) =>
                    texts
                        .map((text) => measureHomeText(context, text, style))
                        .fold<double>(0, (a, b) => a > b ? a : b)
                        .ceilToDouble();
                final labelWidth = widest(bucketLabels, labelStyle);
                final countWidth = widest(counts, countStyle);
                final needed = dotSize + dotGap + labelWidth + columnGap + countWidth;
                final scale = needed > constraints.maxWidth ? constraints.maxWidth / needed : 1.0;
                final rows = Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < bucketLabels.length; i++)
                      Row(
                        key: ValueKey('utxo-status-bucket-$i'),
                        children: [
                          Container(
                            width: dotSize,
                            height: dotSize,
                            decoration: BoxDecoration(
                              color: legibleOn(bucketColors[i], colors.homeSurface),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: dotGap),
                          SizedBox(
                            width: labelWidth,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(bucketLabels[i], maxLines: 1, style: labelStyle),
                            ),
                          ),
                          const SizedBox(width: columnGap),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(counts[i], maxLines: 1, style: countStyle),
                            ),
                          ),
                        ],
                      ),
                  ],
                );
                return FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: constraints.maxWidth / scale,
                    height: constraints.maxHeight / scale,
                    child: rows,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
