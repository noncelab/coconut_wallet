import 'dart:ui' as ui;

import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/model/wallet/wallet_balance_history_point.dart';
import 'package:flutter/material.dart';

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

  const WalletBalanceHistoryChart({super.key, required this.points, required this.revision, this.targetSats});

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
