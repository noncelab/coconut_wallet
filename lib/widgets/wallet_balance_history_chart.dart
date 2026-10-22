import 'dart:ui' as ui;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_balance_history_point.dart';
import 'package:coconut_wallet/services/home/home_widget_math.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 목표 때문에 잔액 변화가 눌리지 않도록 축 확장을 잔액 범위의 25%로 제한한다.
({double minimum, double maximum, bool targetAbove, bool targetBelow}) walletBalanceChartRange(
  List<num> balances,
  int? targetSats,
) {
  if (balances.isEmpty) return (minimum: 0, maximum: 1, targetAbove: false, targetBelow: false);
  final values = balances.map((value) => value.toDouble());
  var minimum = values.reduce((a, b) => a < b ? a : b);
  var maximum = values.reduce((a, b) => a > b ? a : b);
  // 잔액이 일정하면 그 값의 ±5%를 기본 범위로 사용한다. 0원도 유효한 축을 갖는다.
  if (minimum == maximum) {
    final padding = maximum.abs() * 0.05;
    minimum -= padding < 1 ? 1 : padding;
    maximum += padding < 1 ? 1 : padding;
    if (balances.first >= 0 && minimum < 0) minimum = 0;
  }
  final allowance = (maximum - minimum) * 0.25;
  final validTarget = targetSats != null && targetSats > 0;
  final targetAbove = validTarget && targetSats > maximum + allowance;
  final targetBelow = validTarget && targetSats < minimum - allowance;
  if (validTarget && !targetAbove && !targetBelow) {
    if (targetSats < minimum) minimum = targetSats.toDouble();
    if (targetSats > maximum) maximum = targetSats.toDouble();
  }
  return (minimum: minimum, maximum: maximum, targetAbove: targetAbove, targetBelow: targetBelow);
}

class WalletBalanceHistoryChart extends StatefulWidget {
  final List<WalletBalanceHistoryPoint> points;
  final int revision;
  final int? targetSats;
  final BitcoinUnit? axisUnit;
  final bool cardPresentation;

  const WalletBalanceHistoryChart({
    super.key,
    required this.points,
    required this.revision,
    this.targetSats,
    this.axisUnit,
    this.cardPresentation = false,
  });

  @override
  State<WalletBalanceHistoryChart> createState() => _WalletBalanceHistoryChartState();
}

class _WalletBalanceHistoryChartState extends State<WalletBalanceHistoryChart> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void didUpdateWidget(covariant WalletBalanceHistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.axisUnit != null && widget.points.isNotEmpty) {
      return _CompactBalanceChart(
        points: widget.points,
        unit: widget.axisUnit!,
        targetSats: widget.targetSats,
        cardPresentation: widget.cardPresentation,
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder:
          (context, _) => CustomPaint(
            painter: _WalletBalanceHistoryPainter(
              points: widget.points,
              targetSats: widget.targetSats,
              progress: Curves.easeOutCubic.transform(_controller.value),
              lineColor: context.coconutColors.homeChartLine,
              targetColor: context.coconutColors.secondaryText,
            ),
            size: Size.infinite,
          ),
    );
  }
}

/// The focused history graph's compact presentation, without a selected point.
class _CompactBalanceChart extends StatelessWidget {
  final List<WalletBalanceHistoryPoint> points;
  final BitcoinUnit unit;
  final int? targetSats;
  final bool cardPresentation;

  const _CompactBalanceChart({
    required this.points,
    required this.unit,
    this.targetSats,
    required this.cardPresentation,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final balances = [for (final point in points) point.balance];
    final range = walletBalanceChartRange(balances, targetSats);
    final axis = HomeWidgetMath.balanceAxisRange(range.minimum.floor(), range.maximum.ceil());
    final intervals = cardPresentation ? 2 : 4;
    final ticks = [for (var i = 0; i <= intervals; i++) axis.maximum - (axis.maximum - axis.minimum) * i ~/ intervals];
    final labelStyle = CoconutTypography.caption_10_Number.copyWith(color: colors.tertiaryText);
    final dateStyle = (cardPresentation ? CoconutTypography.caption_10 : CoconutTypography.body3_12).copyWith(
      color: colors.secondaryText,
    );
    final datePainter = TextPainter(
      text: TextSpan(text: '0', style: dateStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final dateHeaderHeight = datePainter.height + 8;
    datePainter.dispose();
    Widget dates() => Row(
      key: const Key('wallet-balance-chart-dates'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final index in {0, (points.length - 1) ~/ 2, points.length - 1})
          Text(
            DateFormat(
              cardPresentation ? t.wallet_card_detail_screen.chart_date_format : 'yy.MM.dd',
            ).format(points[index].timestamp),
            style: dateStyle,
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!cardPresentation) ...[
          Text(unit.symbol, style: CoconutTypography.caption_10.copyWith(color: colors.tertiaryText)),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                key: const Key('wallet-balance-chart-value-axis'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cardPresentation) SizedBox(height: dateHeaderHeight),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [for (final tick in ticks) Text(unit.displayBitcoinAmount(tick), style: labelStyle)],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (cardPresentation) ...[dates(), const SizedBox(height: 8)],
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            painter: _CompactBalanceGridPainter(
                              minimum: axis.minimum,
                              maximum: axis.maximum,
                              target: range.targetAbove || range.targetBelow ? null : targetSats,
                              gridColor: colors.tertiaryText.withValues(alpha: 0.2),
                              targetColor: cardPresentation ? colors.homeChartLine : colors.secondaryText,
                              intervals: intervals,
                            ),
                          ),
                          HomeSparkline(values: balances, minimum: axis.minimum, maximum: axis.maximum, strokeWidth: 2),
                          if (cardPresentation &&
                              targetSats != null &&
                              targetSats! > 0 &&
                              !range.targetAbove &&
                              !range.targetBelow)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final y =
                                    2 +
                                    (constraints.maxHeight - 4) *
                                        (1 - (targetSats! - axis.minimum) / (axis.maximum - axis.minimum));
                                final label = '${t.hodl_insights.goal} ${unit.displayBitcoinAmount(targetSats!)}';
                                final style = CoconutTypography.caption_10.copyWith(color: colors.homeChartLine);
                                final painter = TextPainter(
                                  text: TextSpan(text: label, style: style),
                                  textDirection: Directionality.of(context),
                                  textScaler: MediaQuery.textScalerOf(context),
                                  maxLines: 1,
                                )..layout(maxWidth: constraints.maxWidth);
                                final labelHeight = painter.height;
                                painter.dispose();
                                // Keep 1px clear of the 0.5px stroke, including at the bottom edge.
                                const gap = 1 + 0.5 / 2;
                                final top =
                                    y + gap + labelHeight <= constraints.maxHeight ? y + gap : y - gap - labelHeight;
                                return Stack(
                                  children: [
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: top,
                                      child: Text(
                                        label,
                                        textAlign: TextAlign.end,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: style,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!cardPresentation) ...[const SizedBox(height: 12), dates()],
      ],
    );
  }
}

class _CompactBalanceGridPainter extends CustomPainter {
  final int minimum;
  final int maximum;
  final int? target;
  final Color gridColor;
  final Color targetColor;
  final int intervals;

  const _CompactBalanceGridPainter({
    required this.minimum,
    required this.maximum,
    required this.target,
    required this.gridColor,
    required this.targetColor,
    required this.intervals,
  });

  @override
  void paint(Canvas canvas, Size size) {
    void dashedLine(double y, Color color) {
      final paint =
          Paint()
            ..color = color
            ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset((x + 4).clamp(0, size.width), y), paint);
      }
    }

    for (var i = 0; i <= intervals; i++) {
      dashedLine(2 + (size.height - 4) * i / intervals, gridColor);
    }
    final goal = target;
    if (goal != null && goal > 0 && goal >= minimum && goal <= maximum) {
      final y = 2 + (size.height - 4) * (1 - (goal - minimum) / (maximum - minimum));
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = targetColor
          ..strokeWidth = 0.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CompactBalanceGridPainter oldDelegate) =>
      minimum != oldDelegate.minimum ||
      maximum != oldDelegate.maximum ||
      target != oldDelegate.target ||
      intervals != oldDelegate.intervals ||
      gridColor != oldDelegate.gridColor ||
      targetColor != oldDelegate.targetColor;
}

class _WalletBalanceHistoryPainter extends CustomPainter {
  final List<WalletBalanceHistoryPoint> points;
  final int? targetSats;
  final double progress;
  final Color lineColor;
  final Color targetColor;

  const _WalletBalanceHistoryPainter({
    required this.points,
    required this.progress,
    required this.lineColor,
    required this.targetColor,
    this.targetSats,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || points.isEmpty || progress <= 0) return;

    final balances = points.map((point) => point.balance.toDouble()).toList();
    final range = walletBalanceChartRange(balances, targetSats);
    final minBalance = range.minimum;
    final maxBalance = range.maximum;
    final target = targetSats;

    final chartPath = Path();
    final coordinates = <Offset>[];
    final firstTimestamp = points.first.timestamp.millisecondsSinceEpoch;
    final lastTimestamp = points.last.timestamp.millisecondsSinceEpoch;
    final timestampRange = lastTimestamp - firstTimestamp;
    for (var index = 0; index < points.length; index++) {
      final x =
          timestampRange <= 0
              ? size.width
              : size.width * (points[index].timestamp.millisecondsSinceEpoch - firstTimestamp) / timestampRange;
      final normalized = (points[index].balance - minBalance) / (maxBalance - minBalance);
      final y = size.height - (normalized * (size.height - 6)) - 3;
      coordinates.add(Offset(x, y));
    }

    chartPath.moveTo(coordinates.first.dx, coordinates.first.dy);
    for (var index = 1; index < coordinates.length; index++) {
      final previous = coordinates[index - 1];
      final current = coordinates[index];
      final midpointX = (previous.dx + current.dx) / 2;
      chartPath.cubicTo(midpointX, previous.dy, midpointX, current.dy, current.dx, current.dy);
    }

    if (target != null && target > 0 && !range.targetAbove && !range.targetBelow) {
      final y = size.height - (target - minBalance) / (maxBalance - minBalance) * (size.height - 6) - 3;
      final paint =
          Paint()
            ..color = targetColor
            ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 10) {
        canvas.drawLine(Offset(x, y), Offset((x + 5).clamp(0, size.width), y), paint);
      }
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    final fillPath =
        Path.from(chartPath)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
          lineColor.withValues(alpha: 0.24),
          lineColor.withValues(alpha: 0),
        ]),
    );
    canvas.drawPath(
      chartPath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WalletBalanceHistoryPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.points != points ||
        oldDelegate.targetSats != targetSats ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.targetColor != targetColor;
  }
}
