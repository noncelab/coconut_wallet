import 'dart:ui' as ui;

import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/model/wallet/wallet_balance_history_point.dart';
import 'package:flutter/material.dart';

class WalletBalanceHistoryChart extends StatefulWidget {
  final List<WalletBalanceHistoryPoint> points;
  final int revision;

  const WalletBalanceHistoryChart({super.key, required this.points, required this.revision});

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
              progress: Curves.easeOutCubic.transform(_controller.value),
              lineColor: context.coconutColors.textHighlight,
            ),
            size: Size.infinite,
          ),
    );
  }
}

class _WalletBalanceHistoryPainter extends CustomPainter {
  final List<WalletBalanceHistoryPoint> points;
  final double progress;
  final Color lineColor;

  const _WalletBalanceHistoryPainter({required this.points, required this.progress, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || points.isEmpty || progress <= 0) return;

    final balances = points.map((point) => point.balance.toDouble()).toList();
    var minBalance = balances.reduce((a, b) => a < b ? a : b);
    var maxBalance = balances.reduce((a, b) => a > b ? a : b);
    if (minBalance == maxBalance) {
      minBalance -= 1;
      maxBalance += 1;
    }

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
    return oldDelegate.progress != progress || oldDelegate.points != points || oldDelegate.lineColor != lineColor;
  }
}
