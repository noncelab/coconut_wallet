import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_bucket.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_chart_bubble.dart';
import 'package:coconut_wallet/utils/utxo_amount_format_util.dart';
import 'package:coconut_wallet/utils/utxo_tier_theme.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class UtxoSummaryChart extends StatelessWidget {
  final List<UtxoBucket> buckets;
  final int totalSats;
  final int coinCount;
  final int availableCount;
  final int availableSats;
  final int lockedCount;
  final int lockedSats;
  final BitcoinUnit currentUnit;
  final VoidCallback? onBalanceTap;
  final bool hasReusedAddresses;

  const UtxoSummaryChart({
    super.key,
    required this.buckets,
    required this.totalSats,
    required this.coinCount,
    required this.availableCount,
    required this.availableSats,
    required this.lockedCount,
    required this.lockedSats,
    required this.currentUnit,
    this.onBalanceTap,
    this.hasReusedAddresses = false,
  });

  static const double estimatedHeight = 350;

  @override
  Widget build(BuildContext context) {
    final tierTheme = context.watch<PreferenceProvider>().utxoTierTheme;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CoconutColors.black, Color(0xFF1D1D1D)],
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.utxo_list_screen.total_balance,
              style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.gray400),
            ),
            GestureDetector(
              onTap: onBalanceTap,
              behavior: HitTestBehavior.opaque,
              child: Text(
                '$coinCount coins • ${formatUtxoAmountForDisplay(totalSats, currentUnit)}',
                style: CoconutTypography.heading4_18_NumberBold.setColor(CoconutColors.white),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AvailabilityChip(
                    label: t.utxo_detail_screen.utxo_unlocked,
                    count: availableCount,
                    sats: availableSats,
                    formatBalance: (s) => formatUtxoAmountForDisplay(s, currentUnit),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AvailabilityChip(
                    label: t.utxo_detail_screen.utxo_locked,
                    count: lockedCount,
                    sats: lockedSats,
                    formatBalance: (s) => formatUtxoAmountForDisplay(s, currentUnit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _BarChart(buckets: buckets, tierTheme: tierTheme, currentUnit: currentUnit),
            if (hasReusedAddresses) ...[
              const SizedBox(height: 12),
              Tooltip(
                message: t.utxo_list_screen.reused_address,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CoconutColors.hotPink.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(4, 4, 4, 5),
                            decoration: const BoxDecoration(color: CoconutColors.hotPink, shape: BoxShape.circle),
                            child: SvgPicture.asset(
                              'assets/svg/triangle-warning.svg',
                              width: 10,
                              height: 10,
                              colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.utxo_list_screen.reused_address_legend,
                            style: CoconutTypography.caption_10_Bold.setColor(CoconutColors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.utxo_list_screen.reused_address,
                        style: CoconutTypography.caption_10.setColor(CoconutColors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  final String label;
  final int count;
  final int sats;
  final String Function(int) formatBalance;

  const _AvailabilityChip({required this.label, required this.count, required this.sats, required this.formatBalance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: CoconutColors.gray800, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label • $count coins', style: CoconutTypography.caption_10.setColor(CoconutColors.gray500)),
          const SizedBox(height: 4),
          Text(formatBalance(sats), style: CoconutTypography.body3_12_Number.setColor(CoconutColors.white)),
        ],
      ),
    );
  }
}

class _BarChart extends StatefulWidget {
  final List<UtxoBucket> buckets;
  final UtxoTierTheme tierTheme;
  final BitcoinUnit currentUnit;

  const _BarChart({required this.buckets, required this.tierTheme, required this.currentUnit});

  @override
  State<_BarChart> createState() => _BarChartState();
}

/// 태그 차트와 동일한 overlay 불투명도
const double _overlayOpacity = 0.6;

class _BarChartState extends State<_BarChart> {
  static const double _barMaxHeight = 80;
  int? _tappedBucketIndex;
  Timer? _bubbleDismissTimer;

  @override
  void dispose() {
    _bubbleDismissTimer?.cancel();
    super.dispose();
  }

  void _scheduleBubbleDismiss(int? tappedIndex) {
    _bubbleDismissTimer?.cancel();
    if (tappedIndex != null) {
      _bubbleDismissTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _tappedBucketIndex == tappedIndex) {
          setState(() => _tappedBucketIndex = null);
        }
      });
    }
  }

  void _showIntervalInfoModal(BuildContext context, UtxoTierTheme tierTheme) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CoconutColors.gray900,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.utxo_overview_screen.interval_info_title,
                    style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white),
                  ),
                  const SizedBox(height: 16),
                  ...utxoBucketRanges.map((r) {
                    final isDustRange = r.max <= dustLimit;
                    final isWhale = r.label == 'whale';
                    final rangeStr =
                        isWhale
                            ? '≥ 10 ${t.btc}'
                            : (isDustRange
                                ? '${r.min.toThousandsSeparatedString()} ~ ${r.max.toThousandsSeparatedString()} ${t.sats}'
                                : '${formatUtxoAmountForDisplay(r.min, BitcoinUnit.btc)} ~ ${formatUtxoAmountForDisplay(r.max, BitcoinUnit.btc)}');
                    final color = tierTheme.colorForSats(r.max);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          SizedBox(
                            width: 54,
                            child: Text(
                              r.label,
                              style: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray400),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              rangeStr,
                              style: CoconutTypography.body3_12_Number.setColor(CoconutColors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.buckets.isEmpty) return const SizedBox.shrink();

    final maxCount = widget.buckets.map((b) => b.utxos.length).reduce((a, b) => a > b ? a : b).toDouble();
    final maxCountClamped = maxCount < 1 ? 1.0 : maxCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -8,
          right: -8,
          child: SizedBox(
            width: 26,
            height: 26,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showIntervalInfoModal(context, widget.tierTheme),
                borderRadius: BorderRadius.circular(20),
                splashColor: CoconutColors.gray500.withValues(alpha: 0.2),
                highlightColor: CoconutColors.gray500.withValues(alpha: 0.1),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.info_outline_rounded, size: 18, color: CoconutColors.gray500),
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: CoconutColors.gray800,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(48),
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children:
                    widget.buckets.asMap().entries.map((entry) {
                      final index = entry.key;
                      final bucket = entry.value;
                      final count = bucket.utxos.length;
                      final heightRatio = count / maxCountClamped;
                      final barHeight = _barMaxHeight * heightRatio;
                      final isTapped = _tappedBucketIndex == index;
                      var color = widget.tierTheme.colorForSats(bucket.maxSats);
                      if (!isTapped) {
                        color = Color.lerp(color, const Color(0xFF1D1D1D), _overlayOpacity)!;
                      }

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            final newIndex = _tappedBucketIndex == index ? null : index;
                            setState(() => _tappedBucketIndex = newIndex);
                            _scheduleBubbleDismiss(newIndex);
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      height: _barMaxHeight,
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        width: double.infinity,
                                        height: barHeight.clamp(4.0, _barMaxHeight),
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                                        ),
                                      ),
                                    ),
                                    Transform.translate(
                                      offset: const Offset(0, -4),
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: CoconutColors.gray800,
                                          borderRadius: BorderRadius.circular(999),
                                          boxShadow: [
                                            BoxShadow(
                                              color: CoconutColors.black.withValues(alpha: 0.4),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$count',
                                          style: CoconutTypography.caption_10_NumberBold.setColor(CoconutColors.white),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      bucket.label,
                                      style: CoconutTypography.caption_10.setColor(CoconutColors.gray500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
              if (_tappedBucketIndex != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: _barMaxHeight + 24,
                  height: 38,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      widget.buckets.length,
                      (index) => Expanded(
                        child: Center(
                          child:
                              index == _tappedBucketIndex
                                  ? Builder(
                                    builder: (context) {
                                      final bucket = widget.buckets[index];
                                      final balance = formatUtxoBalanceForTooltip(
                                        bucket.utxos.fold<int>(0, (s, u) => s + u.amount),
                                        widget.currentUnit,
                                        isDustBucket: bucket.label == 'dust',
                                      );
                                      final text = t.utxo_overview_screen.amount_bubble_with_count(
                                        count: bucket.utxos.length,
                                        balance: balance,
                                      );
                                      return OverflowBox(
                                        alignment: Alignment.center,
                                        maxWidth: 120,
                                        child: UtxoChartBubble(text: text, maxWidth: 150),
                                      );
                                    },
                                  )
                                  : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
