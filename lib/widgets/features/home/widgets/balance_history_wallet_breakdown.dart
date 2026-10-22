import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card_background.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart' show WalletContentTheme;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BalanceHistoryWalletSlice {
  final WalletItemBase wallet;
  final int balance;
  final List<TransactionRecord> transactions;

  const BalanceHistoryWalletSlice({required this.wallet, required this.balance, required this.transactions});

  int get change => transactions.fold(0, (sum, tx) => sum + tx.amount);
}

/// Water-fill the small segments first, leaving the remaining shares proportional.
Map<int, double> balanceHistoryShareWidths(Map<int, int> balances, double width, {double minimumWidth = 24}) {
  final remaining = Map<int, int>.fromEntries(balances.entries.where((entry) => entry.value > 0));
  final result = {for (final id in balances.keys) id: 0.0};
  var available = math.max(width, remaining.length * minimumWidth);
  while (remaining.isNotEmpty) {
    final total = remaining.values.fold<int>(0, (sum, amount) => sum + amount);
    final small = remaining.keys.where((id) => available * remaining[id]! / total < minimumWidth).toList();
    if (small.isEmpty) {
      for (final entry in remaining.entries) {
        result[entry.key] = available * entry.value / total;
      }
      break;
    }
    for (final id in small) {
      result[id] = minimumWidth;
      available -= minimumWidth;
      remaining.remove(id);
    }
  }
  return result;
}

class BalanceHistoryWalletBreakdown extends StatefulWidget {
  final List<BalanceHistoryWalletSlice> slices;
  final String periodLabel;
  final DateTime? focusedDate;
  final bool singleWallet;
  final String Function(int sats) amountText;

  const BalanceHistoryWalletBreakdown({
    super.key,
    required this.slices,
    required this.periodLabel,
    required this.focusedDate,
    this.singleWallet = false,
    required this.amountText,
  });

  @override
  State<BalanceHistoryWalletBreakdown> createState() => _BalanceHistoryWalletBreakdownState();
}

class _BalanceHistoryWalletBreakdownState extends State<BalanceHistoryWalletBreakdown> {
  final ScrollController _scroll = ScrollController();
  int? _selectedId;
  bool _visible = false;
  bool _reveal = false;

  @override
  void initState() {
    super.initState();
    _chooseWallet();
    _visible = widget.focusedDate != null || widget.singleWallet;
  }

  void _chooseWallet() {
    final positive = widget.slices.where((slice) => slice.balance > 0).toList();
    if (!positive.any((slice) => slice.wallet.id == _selectedId)) {
      _selectedId = positive.isEmpty ? null : positive.first.wallet.id;
    }
  }

  @override
  void didUpdateWidget(covariant BalanceHistoryWalletBreakdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    _chooseWallet();
    if (widget.singleWallet || (widget.focusedDate != null && widget.focusedDate != oldWidget.focusedDate)) {
      _visible = true;
      _reveal = true;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final appearances = context.watchWalletAppearance();
    final selected = widget.slices.where((slice) => slice.wallet.id == _selectedId).firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final target = _ShareWidths(
          balanceHistoryShareWidths({for (final slice in widget.slices) slice.wallet.id: slice.balance}, width),
        );
        return TweenAnimationBuilder<_ShareWidths>(
          tween: _ShareWidthsTween(end: target),
          duration: Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 320),
          curve: Curves.easeInOutCubic,
          builder: (context, geometry, _) {
            var cursor = 0.0;
            var center = 0.0;
            final segments = <Widget>[];
            for (final slice in widget.slices) {
              final segmentWidth = geometry.values[slice.wallet.id] ?? 0;
              if (slice.wallet.id == _selectedId) center = cursor + segmentWidth / 2;
              cursor += segmentWidth;
              if (segmentWidth <= 0) continue;
              final appearance = appearances?.appearanceOf(slice.wallet) ?? WalletAppearance.of(slice.wallet);
              final isSelected = slice.wallet.id == _selectedId && _visible;
              segments.add(
                SizedBox(
                  width: segmentWidth,
                  height: 28,
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label: '${slice.wallet.name}, ${widget.amountText(slice.balance)}',
                    child: GestureDetector(
                      key: ValueKey('balance-history-share-${slice.wallet.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap:
                          slice.balance <= 0
                              ? null
                              : () => setState(() {
                                _selectedId = slice.wallet.id;
                                _visible = true;
                                _reveal = true;
                              }),
                      child: Padding(
                        padding: EdgeInsets.only(right: cursor < geometry.total - 0.01 ? 2 : 0),
                        child: ClipRect(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              RepaintBoundary(
                                child: WalletCardBackground(
                                  background: appearance.background,
                                  photoFile: appearances?.photoFileFor(slice.wallet.id),
                                ),
                              ),
                              if (isSelected && segmentWidth > 48)
                                WalletContentTheme(
                                  background: appearance.background,
                                  child: Builder(
                                    builder:
                                        (context) => Center(
                                          child: Text(
                                            slice.wallet.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: CoconutTypography.body3_12_Bold.copyWith(
                                              color: context.coconutColors.primaryText,
                                            ),
                                          ),
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            if (_reveal) {
              _reveal = false;
              final selectedCenter = center;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_scroll.hasClients) return;
                _scroll.animateTo(
                  (selectedCenter - width / 2).clamp(0.0, _scroll.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                );
              });
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.singleWallet)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ColoredBox(
                      color: colors.surfaceMuted,
                      child: SingleChildScrollView(
                        key: const Key('balance-history-shares'),
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: math.max(width, geometry.total),
                          height: 28,
                          child: Row(children: segments),
                        ),
                      ),
                    ),
                  ),
                if (_selectedId == null) ...[
                  const SizedBox(height: 16),
                  Text(
                    t.wallet_list.balance_history_detail.no_wallets,
                    style: CoconutTypography.body3_12.copyWith(color: colors.secondaryText),
                  ),
                ],
                if (_visible && selected != null && selected.balance > 0) ...[
                  if (!widget.singleWallet) const SizedBox(height: 2),
                  AnimatedBuilder(
                    animation: _scroll,
                    builder:
                        (context, child) => CustomPaint(
                          key: !widget.singleWallet ? const Key('balance-history-share-pointer') : null,
                          painter: BalanceHistorySharePointer(
                            center - (_scroll.hasClients ? _scroll.offset : 0),
                            colors.surfaceMuted,
                            showPointer: !widget.singleWallet,
                          ),
                          child: Padding(padding: EdgeInsets.only(top: !widget.singleWallet ? 14 : 0), child: child),
                        ),
                    child: CoconutToolTip(
                      key: const Key('balance-history-share-tooltip'),
                      tooltipType: CoconutTooltipType.fixed,
                      showIcon: false,
                      backgroundColor: Colors.transparent,
                      borderColor: Colors.transparent,
                      borderRadius: 24,
                      padding: const EdgeInsets.all(16),
                      richText: RichText(
                        text: TextSpan(
                          children: [
                            WidgetSpan(
                              child: SizedBox(
                                width: math.max(0, width - 34),
                                child: _details(
                                  context,
                                  selected,
                                  showName: widget.singleWallet || (geometry.values[_selectedId] ?? 0) <= 48,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _details(BuildContext context, BalanceHistoryWalletSlice slice, {required bool showName}) {
    final colors = context.coconutColors;
    final sent = slice.transactions.where((tx) => tx.transactionType == TransactionType.sent).toList();
    final received = slice.transactions.where((tx) => tx.transactionType == TransactionType.received).toList();
    final organized = slice.transactions.where((tx) => tx.transactionType == TransactionType.self).toList();
    final sentAmount = sent.fold<int>(0, (sum, tx) => sum + tx.amount).abs();
    final receivedAmount = received.fold<int>(0, (sum, tx) => sum + tx.amount).abs();
    final change = '${slice.change >= 0 ? '+' : '-'}${widget.amountText(slice.change.abs())}';
    String flow(String label, int count, int amount, String sign) =>
        '$label ${t.wallet_list.balance_history_detail.flow_summary(count: count, amount: '$sign${widget.amountText(amount)}')}';
    Widget text(String value, {bool bold = false}) => Text(
      value,
      style: (bold ? CoconutTypography.body3_12_Bold : CoconutTypography.body3_12).copyWith(color: colors.primaryText),
    );
    TableRow row(String label, Widget value) => TableRow(
      children: [
        Padding(padding: const EdgeInsets.only(right: 16, bottom: 12), child: text(label, bold: true)),
        Padding(padding: const EdgeInsets.only(bottom: 0), child: value),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showName) ...[text(slice.wallet.name, bold: true), const SizedBox(height: 12)],
        Table(
          columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
          children: [
            row(t.home_edit.period, text(widget.periodLabel)),
            row(
              t.wallet_list.balance_history_detail.balance_label,
              text('${widget.amountText(slice.balance)} ($change)'),
            ),
            row(
              t.wallet_list.balance_history_detail.transactions_label,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  text(flow(t.home_widgets.sent, sent.length, sentAmount, '-')),
                  const SizedBox(height: 8),
                  text(flow(t.home_widgets.received, received.length, receivedAmount, '+')),
                  if (organized.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    text(
                      flow(
                        t.home_widgets.organized,
                        organized.length,
                        organized.fold<int>(0, (sum, tx) => sum + tx.amount).abs(),
                        '-',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ShareWidths {
  final Map<int, double> values;
  const _ShareWidths(this.values);
  double get total => values.values.fold(0, (sum, value) => sum + value);
  @override
  bool operator ==(Object other) => other is _ShareWidths && mapEquals(values, other.values);
  @override
  int get hashCode => Object.hashAllUnordered(values.entries.map((entry) => Object.hash(entry.key, entry.value)));
}

class _ShareWidthsTween extends Tween<_ShareWidths> {
  _ShareWidthsTween({required _ShareWidths end}) : super(end: end);
  @override
  _ShareWidths lerp(double t) => _ShareWidths({
    for (final id in {...begin!.values.keys, ...end!.values.keys})
      id: (begin!.values[id] ?? 0) * (1 - t) + (end!.values[id] ?? 0) * t,
  });
}

/// One silhouette keeps the pointer attached even when its tip is beside a rounded corner.
class BalanceHistorySharePointer extends CustomPainter {
  final double center;
  final Color color;
  final bool showPointer;
  const BalanceHistorySharePointer(this.center, this.color, {this.showPointer = true});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final top = showPointer ? 14.0 : 0.0;
    final radius = math.min(24.0, math.min(size.width / 2, (size.height - top) / 2));
    final visible = showPointer && center >= 0 && center <= size.width;
    // Shorten only the corner adjacent to the arrow, so its base is on the top edge.
    final leftRadius = visible ? math.min(radius, math.max(0.0, center - 9)) : radius;
    final rightRadius = visible ? math.min(radius, math.max(0.0, size.width - center - 9)) : radius;
    final path = Path()..moveTo(leftRadius, top);
    if (visible) {
      path
        ..lineTo(math.max(leftRadius, center - 9), top)
        ..lineTo(center, 0)
        ..lineTo(math.min(size.width - rightRadius, center + 9), top);
    }
    path
      ..lineTo(size.width - rightRadius, top)
      ..quadraticBezierTo(size.width, top, size.width, top + rightRadius)
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(size.width, size.height, size.width - radius, size.height)
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..lineTo(0, top + leftRadius)
      ..quadraticBezierTo(0, top, leftRadius, top)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant BalanceHistorySharePointer oldDelegate) =>
      center != oldDelegate.center || color != oldDelegate.color || showPointer != oldDelegate.showPointer;
}
