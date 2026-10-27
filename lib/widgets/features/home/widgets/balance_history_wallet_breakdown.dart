import 'package:coconut_wallet/widgets/features/home/widgets/balance_history_edge_painter.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
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
  bool _reveal = false;
  double _edgeOverscroll = 0;

  @override
  void initState() {
    super.initState();
    _chooseWallet();
  }

  void _chooseWallet() {
    final positive = widget.slices.where((slice) => slice.balance > 0).toList();
    if (!positive.any((slice) => slice.wallet.id == _selectedId)) {
      _selectedId =
          positive.firstOrNull?.wallet.id ??
          widget.slices.where((slice) => slice.transactions.isNotEmpty).firstOrNull?.wallet.id;
    }
  }

  @override
  void didUpdateWidget(covariant BalanceHistoryWalletBreakdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    _chooseWallet();
    final sharesChanged =
        widget.slices.length != oldWidget.slices.length ||
        widget.slices.indexed.any((entry) {
          final previous = oldWidget.slices[entry.$1];
          return entry.$2.wallet.id != previous.wallet.id || entry.$2.balance != previous.balance;
        });
    if (sharesChanged || widget.singleWallet != oldWidget.singleWallet || widget.focusedDate != oldWidget.focusedDate) {
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
    final tooltipColor = Theme.of(context).brightness == Brightness.dark ? colors.surface : colors.surfaceMuted;
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
              final background =
                  appearance.background ??
                  WalletColorBackground.of(
                    slice.wallet.walletImportSource == WalletImportSource.coconutVault
                        ? WalletVisualStyleUtil.getColor(appearance.colorIndex).color
                        : colors.iconSecondary,
                  );
              final isSelected = slice.wallet.id == _selectedId;
              final border = homeChartSegmentBorderOf(
                context,
                WalletCardBackground.representativeColorOf(background),
                colors.homeBackground,
              );
              final isFirst = cursor - segmentWidth <= 0.01;
              final isLast = cursor >= geometry.total - 0.01;
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
                                _reveal = true;
                              }),
                      child: ColoredBox(
                        color: colors.homeBackground,
                        child: Padding(
                          padding: EdgeInsets.only(right: cursor < geometry.total - 0.01 ? 2 : 0),
                          child: ClipRect(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                RepaintBoundary(
                                  child: WalletCardBackground(
                                    background: background,
                                    photoFile: appearances?.photoFileFor(slice.wallet.id),
                                  ),
                                ),
                                AnimatedOpacity(
                                  opacity: isSelected ? 0 : 1,
                                  duration: Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 200),
                                  child: ColoredBox(color: Colors.black.withValues(alpha: 0.3)),
                                ),
                                if (border != null)
                                  IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: border, width: 1),
                                        borderRadius: BorderRadius.horizontal(
                                          left: Radius.circular(isFirst ? 14 : 0),
                                          right: Radius.circular(isLast ? 14 : 0),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (isSelected && segmentWidth > 48)
                                  WalletContentTheme(
                                    background: background,
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
                ),
              );
            }
            if (_reveal) {
              final animating = geometry != target;
              // Follow the current geometry until the final layout has been applied.
              _reveal = animating;
              final selectedCenter = center;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_scroll.hasClients) return;
                final offset = (selectedCenter - width / 2).clamp(0.0, _scroll.position.maxScrollExtent);
                if (animating) {
                  _scroll.jumpTo(offset);
                } else {
                  _scroll.animateTo(offset, duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic);
                }
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
                      child: NotificationListener<OverscrollIndicatorNotification>(
                        onNotification: (notification) {
                          notification.disallowIndicator();
                          return true;
                        },
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.depth != 0 || notification.metrics.axis != Axis.horizontal) return false;
                            if (notification is OverscrollNotification && notification.dragDetails != null) {
                              setState(
                                () => _edgeOverscroll = (_edgeOverscroll + notification.overscroll).clamp(-96.0, 96.0),
                              );
                            } else if (notification is ScrollEndNotification ||
                                notification is ScrollUpdateNotification) {
                              if (_edgeOverscroll != 0) setState(() => _edgeOverscroll = 0);
                            }
                            return false;
                          },
                          child: Stack(
                            children: [
                              SingleChildScrollView(
                                key: const Key('balance-history-shares'),
                                physics: const ClampingScrollPhysics(),
                                controller: _scroll,
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: math.max(width, geometry.total),
                                  height: 28,
                                  child: Row(children: segments),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: TweenAnimationBuilder<double>(
                                    key: const Key('balance-history-shares-edge-feedback'),
                                    tween: Tween(end: _edgeOverscroll),
                                    duration: Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 160),
                                    curve: Curves.easeOutCubic,
                                    builder:
                                        (context, amount, _) => CustomPaint(
                                          painter: BalanceHistoryEdgePainter(amount, colors.tertiaryText),
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
                if (_selectedId == null) ...[
                  const SizedBox(height: 16),
                  Text(
                    t.wallet_list.balance_history_detail.no_wallets,
                    style: CoconutTypography.body3_12.copyWith(color: colors.secondaryText),
                  ),
                ],
                if (selected != null) ...[
                  if (!widget.singleWallet) const SizedBox(height: 2),
                  AnimatedBuilder(
                    animation: _scroll,
                    builder:
                        (context, child) => CustomPaint(
                          key:
                              !widget.singleWallet && selected.balance > 0
                                  ? const Key('balance-history-share-pointer')
                                  : null,
                          painter: BalanceHistorySharePointer(
                            center - (_scroll.hasClients ? _scroll.offset : 0),
                            tooltipColor,
                            showPointer: !widget.singleWallet && selected.balance > 0,
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(top: !widget.singleWallet && selected.balance > 0 ? 14 : 0),
                            child: child,
                          ),
                        ),
                    child: CoconutToolTip(
                      key: const Key('balance-history-share-tooltip'),
                      tooltipType: CoconutTooltipType.fixed,
                      showIcon: false,
                      backgroundColor: tooltipColor,
                      borderColor: Colors.transparent,
                      borderRadius: 24,
                      padding: const EdgeInsets.all(16),
                      richText: RichText(
                        text: TextSpan(
                          children: [
                            WidgetSpan(
                              child: SizedBox(width: math.max(0, width - 34), child: _details(context, selected)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                for (final slice in widget.slices)
                  if (slice.balance == 0 && slice.transactions.isNotEmpty && slice.wallet.id != _selectedId)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        key: ValueKey('balance-history-zero-balance-summary-${slice.wallet.id}'),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: BorderRadius.circular(24)),
                        child: _details(context, slice),
                      ),
                    ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _details(BuildContext context, BalanceHistoryWalletSlice slice) {
    final colors = context.coconutColors;
    final sent = slice.transactions.where((tx) => tx.transactionType == TransactionType.sent).toList();
    final received = slice.transactions.where((tx) => tx.transactionType == TransactionType.received).toList();
    final organized = slice.transactions.where((tx) => tx.transactionType == TransactionType.self).toList();
    final sentAmount = sent.fold<int>(0, (sum, tx) => sum + tx.amount).abs();
    final receivedAmount = received.fold<int>(0, (sum, tx) => sum + tx.amount).abs();
    final change = '${slice.change >= 0 ? '+' : '-'}${widget.amountText(slice.change.abs())}';
    final numberStyle = CoconutTypography.body3_12_NumberBold.copyWith(color: colors.primaryText);
    List<InlineSpan> flow(String label, int count, int amount, String sign) {
      if (count == 0) {
        return [TextSpan(text: '$label ${t.wallet_list.balance_history_detail.flow_count(count: count)}')];
      }
      const placeholder = '\u0000';
      final parts = t.wallet_list.balance_history_detail
          .flow_summary(count: count, amount: placeholder)
          .split(placeholder);
      return [
        TextSpan(text: '$label ${parts.first}'),
        TextSpan(text: '${amount == 0 ? '' : sign}${widget.amountText(amount)}', style: numberStyle),
        if (parts.length > 1) TextSpan(text: parts.sublist(1).join()),
      ];
    }

    Widget text(String value, {bool bold = true}) => Text(
      value,
      style: (bold ? CoconutTypography.body3_12_Bold : CoconutTypography.body3_12).copyWith(color: colors.primaryText),
    );
    Widget rich(List<InlineSpan> spans) => Text.rich(
      TextSpan(children: spans),
      style: CoconutTypography.body3_12_Bold.copyWith(color: colors.primaryText),
    );
    TableRow row(String label, Widget value) => TableRow(
      children: [
        Padding(padding: const EdgeInsets.only(right: 16, bottom: 12), child: text(label, bold: false)),
        Padding(padding: const EdgeInsets.only(bottom: 0), child: value),
      ],
    );
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(boldText: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Table(
            columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
            children: [
              row(t.name, text(slice.wallet.name)),
              row(t.home_edit.period, text(widget.periodLabel)),
              row(
                t.wallet_list.balance_history_detail.balance_label,
                rich([
                  TextSpan(text: widget.amountText(slice.balance), style: numberStyle),
                  if (slice.change != 0) TextSpan(text: ' ($change)', style: numberStyle),
                ]),
              ),
              row(
                t.wallet_list.balance_history_detail.transactions_label,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    rich(flow(t.home_widgets.sent, sent.length, sentAmount, '-')),
                    const SizedBox(height: 8),
                    rich(flow(t.home_widgets.received, received.length, receivedAmount, '+')),
                    if (organized.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      rich(
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
      ),
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
