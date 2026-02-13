import 'dart:math';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/material.dart';

class SendTransactionFlowCard extends StatefulWidget {
  final List<int?> inputAmounts;
  final List<int> externalOutputAmounts;
  final List<int> changeOutputAmounts;
  final int? fee;
  final BitcoinUnit currentUnit;

  const SendTransactionFlowCard({
    super.key,
    required this.inputAmounts,
    required this.externalOutputAmounts,
    required this.changeOutputAmounts,
    required this.fee,
    required this.currentUnit,
  });

  @override
  State<SendTransactionFlowCard> createState() => _SendTransactionFlowCardState();
}

class _SendTransactionFlowCardState extends State<SendTransactionFlowCard> with SingleTickerProviderStateMixin {
  final GlobalKey _paintAreaKey = GlobalKey();
  List<GlobalKey> _inputKeys = [];
  List<GlobalKey> _outputKeys = [];

  List<Offset> _inputAnchors = const [];
  List<Offset> _outputAnchors = const [];
  AnimationController? _flowController;

  @override
  void initState() {
    super.initState();
    _flowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300))..repeat();
  }

  @override
  void dispose() {
    _flowController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _flowController ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 2300))..repeat();

    final inputNodes = _buildInputNodes(context);
    final outputNodes = _buildOutputNodes(context);

    if (inputNodes.isEmpty || outputNodes.isEmpty) {
      return const SizedBox.shrink();
    }

    _syncNodeKeys(inputNodes.length, outputNodes.length);

    const double rowHeight = 58;
    const double rowGap = 8;
    const double curveWidth = 128;

    final int maxRows = max(inputNodes.length, outputNodes.length);
    final double canvasHeight = maxRows * rowHeight + (maxRows - 1) * rowGap;

    final inputY = _buildAnchorY(
      nodeCount: inputNodes.length,
      containerHeight: canvasHeight,
      rowHeight: rowHeight,
      rowGap: rowGap,
    );
    final outputY = _buildAnchorY(
      nodeCount: outputNodes.length,
      containerHeight: canvasHeight,
      rowHeight: rowHeight,
      rowGap: rowGap,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAnchors());

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: MyColors.transparentWhite_06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: SizedBox(
        key: _paintAreaKey,
        height: canvasHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _flowController!,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _FlowConnectionPainter(
                        inputAnchors: _inputAnchors,
                        outputAnchors: _outputAnchors,
                        flowProgress: _flowController!.value,
                      ),
                    );
                  },
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildNodeStack(
                    nodes: inputNodes,
                    nodeKeys: _inputKeys,
                    anchorY: inputY,
                    height: canvasHeight,
                    rowHeight: rowHeight,
                    isLeft: true,
                  ),
                ),
                const SizedBox(width: curveWidth),
                Expanded(
                  child: _buildNodeStack(
                    nodes: outputNodes,
                    nodeKeys: _outputKeys,
                    anchorY: outputY,
                    height: canvasHeight,
                    rowHeight: rowHeight,
                    isLeft: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeStack({
    required List<_FlowNode> nodes,
    required List<GlobalKey> nodeKeys,
    required List<double> anchorY,
    required double height,
    required double rowHeight,
    required bool isLeft,
  }) {
    return SizedBox(
      height: height,
      child: Stack(
        children: List.generate(nodes.length, (index) {
          return Positioned(
            top: anchorY[index] - rowHeight / 2,
            left: 0,
            right: 0,
            child: _FlowNodeTile(
              key: nodeKeys[index],
              node: nodes[index],
              currentUnit: widget.currentUnit,
              isLeft: isLeft,
            ),
          );
        }),
      ),
    );
  }

  void _syncNodeKeys(int inputCount, int outputCount) {
    if (_inputKeys.length != inputCount) {
      _inputKeys = List.generate(inputCount, (_) => GlobalKey());
    }
    if (_outputKeys.length != outputCount) {
      _outputKeys = List.generate(outputCount, (_) => GlobalKey());
    }
  }

  void _measureAnchors() {
    if (!mounted) {
      return;
    }

    final rootBox = _paintAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (rootBox == null) {
      return;
    }

    final inputAnchors = <Offset>[];
    for (final key in _inputKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) {
        return;
      }
      final globalPoint = box.localToGlobal(Offset(box.size.width - 8, box.size.height / 2));
      inputAnchors.add(rootBox.globalToLocal(globalPoint));
    }

    final outputAnchors = <Offset>[];
    for (final key in _outputKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) {
        return;
      }
      final globalPoint = box.localToGlobal(Offset(-8, box.size.height / 2));
      outputAnchors.add(rootBox.globalToLocal(globalPoint));
    }

    if (!_sameOffsetList(_inputAnchors, inputAnchors) || !_sameOffsetList(_outputAnchors, outputAnchors)) {
      setState(() {
        _inputAnchors = inputAnchors;
        _outputAnchors = outputAnchors;
      });
    }
  }

  bool _sameOffsetList(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if ((a[i].dx - b[i].dx).abs() > 0.5 || (a[i].dy - b[i].dy).abs() > 0.5) {
        return false;
      }
    }
    return true;
  }

  List<_FlowNode> _buildInputNodes(BuildContext context) {
    if (widget.inputAmounts.isEmpty) {
      return [];
    }

    if (widget.inputAmounts.length <= 5) {
      return List.generate(
        widget.inputAmounts.length,
        (index) => _FlowNode(
          type: _FlowNodeType.input,
          title: _localizedInputTitle(context, index + 1),
          amount: widget.inputAmounts[index],
        ),
      );
    }

    return [
      _FlowNode(type: _FlowNodeType.input, title: _localizedInputTitle(context, 1), amount: widget.inputAmounts[0]),
      _FlowNode(type: _FlowNodeType.input, title: _localizedInputTitle(context, 2), amount: widget.inputAmounts[1]),
      _FlowNode(type: _FlowNodeType.input, title: _localizedInputTitle(context, 3), amount: widget.inputAmounts[2]),
      const _FlowNode(type: _FlowNodeType.ellipsis, title: '...', amount: null),
      _FlowNode(
        type: _FlowNodeType.input,
        title: _localizedInputTitle(context, widget.inputAmounts.length),
        amount: widget.inputAmounts.last,
      ),
    ];
  }

  List<_FlowNode> _buildOutputNodes(BuildContext context) {
    final List<_FlowNode> nodes = [];
    final bool hasChange = widget.changeOutputAmounts.isNotEmpty;
    // Show all external outputs when (external output rows + change row) <= 4.
    final int outputAndChangeRowCount = widget.externalOutputAmounts.length + (hasChange ? 1 : 0);
    final bool shouldShowAllExternal = outputAndChangeRowCount <= 4;

    if (shouldShowAllExternal) {
      for (int i = 0; i < widget.externalOutputAmounts.length; i++) {
        nodes.add(
          _FlowNode(
            type: _FlowNodeType.output,
            title: _localizedOutputTitle(context, i + 1),
            amount: widget.externalOutputAmounts[i],
          ),
        );
      }
    } else {
      nodes.add(
        _FlowNode(
          type: _FlowNodeType.output,
          title: _localizedOutputTitle(context, 1),
          amount: widget.externalOutputAmounts.first,
        ),
      );
      nodes.add(const _FlowNode(type: _FlowNodeType.ellipsis, title: '...', amount: null));
      nodes.add(
        _FlowNode(
          type: _FlowNodeType.output,
          title: _localizedOutputTitle(context, widget.externalOutputAmounts.length),
          amount: widget.externalOutputAmounts.last,
        ),
      );
    }

    nodes.add(_FlowNode(type: _FlowNodeType.fee, title: t.fee, amount: widget.fee));

    if (hasChange) {
      nodes.add(
        _FlowNode(
          type: _FlowNodeType.change,
          title: t.change,
          amount: widget.changeOutputAmounts.fold<int>(0, (sum, amount) => sum + amount),
        ),
      );
    }
    return nodes;
  }

  List<double> _buildAnchorY({
    required int nodeCount,
    required double containerHeight,
    required double rowHeight,
    required double rowGap,
  }) {
    final totalHeight = nodeCount * rowHeight + (nodeCount - 1) * rowGap;
    final topPadding = (containerHeight - totalHeight) / 2;
    final step = rowHeight + rowGap;
    return List.generate(nodeCount, (index) => topPadding + rowHeight / 2 + step * index);
  }

  String _localizedInputTitle(BuildContext context, int index) {
    return t.send_confirm_screen.flow_input_title(index: index);
  }

  String _localizedOutputTitle(BuildContext context, int index) {
    return t.send_confirm_screen.flow_output_title(index: index);
  }
}

class _FlowConnectionPainter extends CustomPainter {
  final List<Offset> inputAnchors;
  final List<Offset> outputAnchors;
  final double flowProgress;

  const _FlowConnectionPainter({required this.inputAnchors, required this.outputAnchors, required this.flowProgress});

  @override
  void paint(Canvas canvas, Size size) {
    if (inputAnchors.isEmpty || outputAnchors.isEmpty) {
      return;
    }

    final paint =
        Paint()
          ..color = CoconutColors.gray600
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt;
    final trunkPaint =
        Paint()
          ..color = CoconutColors.gray600
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt;
    final head = flowProgress.clamp(0.0, 1.0);
    final leadStart = (head - 0.1).clamp(0.0, 1.0);
    final leadEnd = (head + 0.1).clamp(0.0, 1.0);
    final glowPaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [Colors.transparent, CoconutColors.primary, CoconutColors.cyan, Colors.transparent],
            stops: [leadStart, (head - 0.015).clamp(0.0, 1.0), (head + 0.015).clamp(0.0, 1.0), leadEnd],
          ).createShader(Offset.zero & size)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt;

    final leftMaxX = inputAnchors.map((point) => point.dx).reduce(max);
    final rightMinX = outputAnchors.map((point) => point.dx).reduce(min);
    final mergeY = inputAnchors.map((point) => point.dy).reduce((a, b) => a + b) / inputAnchors.length;
    final splitY = outputAnchors.map((point) => point.dy).reduce((a, b) => a + b) / outputAnchors.length;
    final hubY = (mergeY + splitY) / 2;

    final availableWidth = max(12.0, rightMinX - leftMaxX);
    final centerX = leftMaxX + availableWidth * 0.5;
    final hub = Offset(centerX, hubY);
    const curve = 0.68;

    Path buildLeftPath(Offset start) {
      final dx = hub.dx - start.dx;
      final dYToHub = hub.dy - start.dy;
      final path = Path()..moveTo(start.dx, start.dy);
      if (dYToHub.abs() < 1.5) {
        path.lineTo(hub.dx, hub.dy);
        return path;
      }
      path.cubicTo(start.dx + dx * curve, start.dy + dYToHub * 0.06, hub.dx - dx * curve, hub.dy, hub.dx, hub.dy);
      return path;
    }

    Path buildRightPath(Offset end) {
      final dx = end.dx - hub.dx;
      final dYFromHub = end.dy - hub.dy;
      final path = Path()..moveTo(hub.dx, hub.dy);
      if (dYFromHub.abs() < 1.5) {
        path.lineTo(end.dx, end.dy);
        return path;
      }
      path.cubicTo(hub.dx + dx * curve, hub.dy, end.dx - dx * curve, end.dy - dYFromHub * 0.06, end.dx, end.dy);
      return path;
    }

    void drawFlowPath(Path path, Paint glowPaint, {double glowTrimStart = 0.0, double glowTrimEnd = 1.0}) {
      canvas.drawPath(path, paint);
      final clampedStart = glowTrimStart.clamp(0.0, 1.0);
      final clampedEnd = glowTrimEnd.clamp(0.0, 1.0);
      if (clampedEnd <= clampedStart) {
        return;
      }
      for (final metric in path.computeMetrics()) {
        final start = metric.length * clampedStart;
        final end = metric.length * clampedEnd;
        if (end - start > 0.5) {
          canvas.drawPath(metric.extractPath(start, end), glowPaint);
        }
      }
    }

    for (final point in inputAnchors) {
      drawFlowPath(buildLeftPath(point), glowPaint);
    }

    const pinchHalf = 0.8;
    final trunkStart = Offset(centerX - pinchHalf, hubY);
    final trunkEnd = Offset(centerX + pinchHalf, hubY);
    canvas.drawLine(trunkStart, trunkEnd, trunkPaint);
    canvas.drawLine(trunkStart, trunkEnd, glowPaint);

    for (final point in outputAnchors) {
      drawFlowPath(buildRightPath(point), glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowConnectionPainter oldDelegate) {
    return oldDelegate.inputAnchors != inputAnchors ||
        oldDelegate.outputAnchors != outputAnchors ||
        oldDelegate.flowProgress != flowProgress;
  }
}

class _FlowNodeTile extends StatelessWidget {
  final _FlowNode node;
  final BitcoinUnit currentUnit;
  final bool isLeft;

  const _FlowNodeTile({super.key, required this.node, required this.currentUnit, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    final isEllipsis = node.type == _FlowNodeType.ellipsis;
    final isChange = node.type == _FlowNodeType.change;
    final amountText =
        node.amount == null
            ? '-'
            : currentUnit == BitcoinUnit.btc
            ? '${BalanceFormatUtil.formatSatoshiToReadableBitcoin(node.amount!)} BTC'
            : currentUnit.displayBitcoinAmount(node.amount, withUnit: true, defaultWhenNull: '-');

    final titleStyle = CoconutTypography.body2_14.copyWith(
      color: isChange ? CoconutColors.cyan : CoconutColors.white,
      height: 1.2,
    );
    final amountStyle = CoconutTypography.caption_10_Number.copyWith(
      color: isChange ? CoconutColors.cyan : CoconutColors.white,
    );

    return Align(
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerLeft,
      child: SizedBox(
        height: 58,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(node.title, style: isEllipsis ? Styles.body1.copyWith(color: CoconutColors.gray400) : titleStyle),
            if (!isEllipsis) ...[const SizedBox(height: 4), Text(amountText, style: amountStyle)],
          ],
        ),
      ),
    );
  }
}

enum _FlowNodeType { input, output, change, fee, ellipsis }

class _FlowNode {
  final _FlowNodeType type;
  final String title;
  final int? amount;

  const _FlowNode({required this.type, required this.title, required this.amount});
}
